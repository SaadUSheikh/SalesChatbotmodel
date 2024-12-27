import streamlit as st
import pandas as pd
from elasticsearch8 import Elasticsearch
import io
from streamlit.components.v1 import html
import requests
import plotly.express as px
import json


##IMP: Here we have implemented a RESTful way of fetching data from the db and not using es client.

def fetch_data_rest(es_host, es_port, es_username, es_password, size=100, current_offset=0):
    url = f"https://{es_host}:{es_port}/melbourne_weather/_search"
    query = {
        "query": {
            "match_all": {}
        },
        "size": size,
        "from": current_offset
    }
    try:
        response = requests.get(url, json=query, auth=(es_username, es_password), verify=False)
        response.raise_for_status()  # raise an exception for HTTP error codes
        data = response.json()
        hits = data['hits']['hits']
        if hits:
            return pd.json_normalize([hit['_source'] for hit in hits]), len(hits)
        else:
            return pd.DataFrame(), 0
    except requests.RequestException as e:
        st.error(f"Failed to fetch data: {e}")
        return pd.DataFrame(), 0

def fetch_data_for_sudo(es_host, es_port, es_username, es_password, es_index="trees_data"):
    url = f"https://{es_host}:{es_port}/{es_index}/_search?scroll=2m"  # Keep the search context alive for 2 minutes
    query = {
        "query": {
            "match_all": {}
        },
        "size": 1000  # Number of results per "page"
    }
    headers = {
        "Content-Type": "application/json"
    }

    # Initial search request
    initial_response = requests.post(url, headers=headers, data=json.dumps(query), auth=(es_username, es_password),verify=False)
    if initial_response.status_code != 200:
        st.error(f"Failed to fetch data: HTTP {initial_response.status_code} - {initial_response.text}")
        return pd.DataFrame()

    # Process initial response
    initial_data = initial_response.json()
    all_hits = initial_data['hits']['hits']
    scroll_id = initial_data['_scroll_id']
    
    # Fetch remaining data with scrolling
    while True:
        scroll_url = f"https://{es_host}:{es_port}/_search/scroll"
        scroll_query = {
            "scroll": "2m",
            "scroll_id": scroll_id
        }
        response = requests.post(scroll_url, headers=headers, data=json.dumps(scroll_query), auth=(es_username, es_password), verify=False)
        if response.status_code != 200:
            st.error(f"Failed to continue scrolling: HTTP {response.status_code} - {response.text}")
            break

        data = response.json()
        hits = data['hits']['hits']
        if not hits:
            break

        all_hits.extend(hits)
        scroll_id = data['_scroll_id']

    return pd.json_normalize([hit['_source'] for hit in all_hits])


# Function to fetch data from Elasticsearch
def fetch_data(es, index, size=100, current_offset=0):
    query = {
        "query": {
            "match_all": {}
        },
        "size": size,
        "from": current_offset
    }
    try:
        response = es.search(index=index, body=query)
        if response['hits']['hits']:
            hits = response['hits']['hits']
            return pd.json_normalize([hit['_source'] for hit in hits]), len(hits)
        else:
            return pd.DataFrame(), 0
    except Exception as e:
        st.error(f"Failed to fetch data: {e}")
        return pd.DataFrame(), 0

def display_dataframe_info(df):
    if not df.empty:
        buffer = io.StringIO()
        df.info(buf=buffer)
        return buffer.getvalue()
    return "No data available."

def clean_weather_data(df):
    # Convert date columns to datetime
    df['current_date_time'] = pd.to_datetime(df['current_date_time'], errors='coerce')
    
    # Fill missing numeric data with mean or interpolate
    numeric_cols = ['latitude', 'longitude', 'temp', 'app_temp', 'dew_point', 'rel_hum', 'delta_t', 'wind_spd', 'wind_gust', 'press_msl', 'low_temp', 'high_temp','rain']
    for col in numeric_cols:
        df[col] = pd.to_numeric(df[col], errors='coerce')
        df[col] = df[col].fillna(df[col].interpolate())  # or use df[col].interpolate()

    # Ensure correct data types
    df['station'] = df['station'].astype(str)
    df['wind_dir'] = df['wind_dir'].astype(str)
    df['high_wind_gust_dir'] = df['high_wind_gust_dir'].astype(str)
    df['high_wind_gust_time'] = pd.to_datetime(df['high_wind_gust_time'], errors='coerce')
    
    df = df[df['station'] != 'nan']

    return df


def clean_tree_data(df):
    # Convert any relevant columns to appropriate data types
    df['latitude'] = pd.to_numeric(df['latitude'], errors='coerce')
    df['longitude'] = pd.to_numeric(df['longitude'], errors='coerce')
    df['tree_age'] = df['tree_age'].astype(str)
    df['status'] = df['status'].astype(str)
    df['easting'] = pd.to_numeric(df['easting'], errors='coerce')
    df['ule'] = df['ule'].astype(str)
    df['htms_id'] = pd.to_numeric(df['htms_id'], errors='coerce')
    df['height'] = pd.to_numeric(df['height'], errors='coerce')
    df['tree_struc'] = df['tree_struc'].astype(str)
    df['tree_healt'] = df['tree_healt'].astype(str)
    df['genus_spec'] = df['genus_spec'].astype(str)

    # Handle missing values for numeric fields
    df['dbh'] = pd.to_numeric(df['dbh'], errors='coerce').fillna(method='bfill')
    df['northing'] = pd.to_numeric(df['northing'], errors='coerce').fillna(df['northing'].mean())

    return df

# Main Streamlit app
def main():
    title_html = """
    <style>
        .title {
            font-size: 29px;
            font-weight: bold;
            color: white;  /* Set text color to white */
            text-align: center;
            margin-top: 10px;  /* Top margin */
            margin-bottom: 30px;  /* Increased bottom margin for more space */
            padding: 20px;  /* Padding around the title */
            width: 100%;  /* Full width */
        }
        /* Add styles for other elements to control spacing further */
        .streamlit-expanderHeader {
            margin-top: 20px;  /* Additional top margin for elements below the title */
        }
    </style>
    <div class='title'>🌳 Data Analysis on Tree Health in Melbourne 🌳</div>
    """
    st.markdown(title_html, unsafe_allow_html=True)  # Ensure to enable HTML rendering

    # Elasticsearch configuration
    es_host = 'localhost'
    es_port = '9200'
    es_index = 'melbourne_weather'
    es_username = 'elastic'
    es_password = st.text_input("Enter the Elasticsearch password:", type="password")

    if es_password:

        # Initialize or get the existing state
        if 'current_offset' not in st.session_state:
            st.session_state['current_offset'] = 0
        if 'global_df' not in st.session_state:
            st.session_state['global_df'] = pd.DataFrame()
        if 'sudo_df' not in st.session_state:
            st.session_state['sudo_df'] = pd.DataFrame()
        
        if st.button("Fetch SUDO Data"):
                if 'sudo_df' not in st.session_state or st.session_state['sudo_df'].empty:
                    with st.spinner('Fetching SUDO data from Elasticsearch...'):
                        df = fetch_data_for_sudo(es_host, es_port, es_username, es_password)
                        if not df.empty:
                            st.session_state['sudo_df'] = df
                            st.success("SUDO data fetched successfully.")
                        else:
                            st.error("No SUDO data found.")
                st.dataframe(st.session_state['sudo_df'])

        if st.button('🔄 Refresh BoM Data'):
            df, fetched_size = fetch_data_rest(es_host, es_port, es_username, es_password, 100, st.session_state['current_offset'])
            if not df.empty:
                st.session_state['global_df'] = pd.concat([st.session_state['global_df'], df], ignore_index=True)
                st.session_state['current_offset'] += fetched_size
                st.dataframe(df)  # Display the new batch of data
                st.success(f"Fetched {fetched_size} new records.")
            else:
                st.info("No more data to fetch or failed to fetch data.")
            
            if fetched_size < 100:
                st.warning("You have reached the end of the data.")
                
        if st.button('Show All BoM Data'):
            if not st.session_state['global_df'].empty:
                st.dataframe(st.session_state['global_df'])
            else:
                st.error("No data to display. Please fetch data first.")

        # st.header("🔍 Exploratory Analysis of Melbourne Weather Data")
        explore_html = """
            <style>
            .title {
                font-size: 29px;
                font-weight: bold;
                color: white;  /* Set text color to white */
                text-align: center;
                margin-top: 10px;  /* Top margin */
                margin-bottom: 30px;  /* Increased bottom margin for more space */
                padding: 20px;  /* Padding around the title */
                width: 100%;  /* Full width */
            }
            /* Add styles for other elements to control spacing further */
            .streamlit-expanderHeader {
                margin-top: 20px;  /* Additional top margin for elements below the title */
            }
        </style>
        <div class='title'>🔍Exploratory Analysis of Melbourne Weather Data</div>
        """
        st.markdown(explore_html, unsafe_allow_html=True)  #enable HTML rendering

        # Always display data if available
        if 'global_df' in st.session_state and not st.session_state['global_df'].empty:
            
            st.session_state['global_df'] = clean_weather_data(st.session_state['global_df'])
            st.write("Weather Data Loaded and Cleaned:")
            st.dataframe(st.session_state['global_df'].head())
            

            st.session_state['sudo_df'] = clean_tree_data(st.session_state['sudo_df'])
            st.write("Tree Data Loaded and Cleaned:")
            st.dataframe(st.session_state['sudo_df'].head())
            
            # st.subheader("First 5 Rows of BoM Data")
            # st.write(st.session_state['global_df'].head())
            
            # st.subheader("First 5 Rows of Trees Data")
            # st.write(st.session_state['sudo_df'].head())

            st.write("Data Information for BoM")
            st.text(display_dataframe_info(st.session_state['global_df']))
            
            st.write("Data Information for Tree Data")
            st.text(display_dataframe_info(st.session_state['sudo_df']))

            st.write("Descriptive Statistics")
            columns_of_interest = ['temp', 'wind_spd', 'rain']
            st.write(st.session_state['global_df'][columns_of_interest].describe())
            
            st.write("Average Rainfall by Station")
            avg_rainfall = st.session_state['global_df'].groupby('station')['rain'].mean().reset_index()
            fig = px.bar(avg_rainfall, x='station', y='rain')
            st.plotly_chart(fig)
            

        else:
            st.write("No data available. Please fetch data first.")

if __name__ == "__main__":
    main()
