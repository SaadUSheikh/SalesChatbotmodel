library(shiny)
library(shinydashboard)

# Defining the UI layout for the dashboard
ui <- dashboardPage(
  
  # Dashboard header with a centered and bold title
  dashboardHeader(
    title = div(
      style = "text-align: center; font-weight: bold; width: 100%;",
      "Amazon Seller Dashboard"
    )
  ),
  
  # Sidebar menu with two items: Dashboard and Data Table
  dashboardSidebar(
    sidebarMenu(
      menuItem("Dashboard", tabName = "dashboard", icon = icon("dashboard")),
      menuItem("Data Table", tabName = "datatable", icon = icon("table"))
    )
  ),
  
  
  
  # Main body
  dashboardBody(
    
    # Custom CSS for styling Aesthetics
    tags$head(
      tags$style(HTML("
        .small-box {
          white-space: normal !important;
          word-wrap: break-word;
        }
        .small-box .inner {
          font-size: 18px !important;
        }

        /* Custom slider styles */
        /* Initial style for the slider thumb (handle) */
        .irs--shiny .irs-bar {
          background-color: #1e90ff;  /* Blue range background */
        }
        .irs--shiny .irs-handle {
          background-color: green;  /* Initial green color for lower value */
        }
        .irs--shiny .irs-line {
          background-color: #d3d3d3;  /* Light gray track background */
        }
        .irs--shiny .irs-line-left {
          background-color: #32cd32;  /* Green for the range that has been selected */
        }
        .irs--shiny .irs-line-right {
          background-color: #d3d3d3;  /* Gray for the unselected range */
        }
        /* Style for the slider labels */
        .irs--shiny .irs-grid-text {
          color: #000000;  /* Black text for the grid labels */
        }
        .irs--shiny .irs-single {
          background-color: #ff4500;  /* Orange background for the current value bubble */
          color: #ffffff;  /* White text inside the value bubble */
        }
      "))
    ),
    
    # Add JavaScript for dynamic color changing of the slider handle
    tags$script(HTML("
      $(document).on('shiny:inputchanged', function(event) {
        if (event.name === 'units_sold') {
          var value = event.value[1];  // Get the upper limit of the slider
          var handle = $('.irs--shiny .irs-handle');  // Get the slider handle element

          if (value <= 25000) {
            handle.css('background-color', 'green');  // Green for low values
          } else if (value > 25000 && value <= 75000) {
            handle.css('background-color', 'yellow');  // Yellow for mid-range values
          } else {
            handle.css('background-color', 'red');  // Red for high values
          }
        }
      });
    ")),
    
    # Define layout of the dashboard's tab panels
    tabItems(
      
      # Dashboard tab layout
      tabItem(tabName = "dashboard",
              
              # First row: selection input boxes for user preferences
              fluidRow(
                box(
                  title = "Select Your Preferences",
                  status = "primary",
                  solidHeader = TRUE,
                  selectInput("selected_category", "Select Categories:", 
                              choices = unique(products_with_categories$category_name), 
                              selected = unique(products_with_categories$category_name)[1],
                              multiple = TRUE),
                  sliderInput("units_sold", "Units Sold Last Month:", 
                              min = 0, max = 100000, value = c(0, 100000)),
                  numericInput("num_records", "Number of Products to Display in Data Table:", value = 10, min = 1, max = 100),
                  sliderInput("prediction_days", "Days Ahead for Prediction:", min = 1, max = 60, value = 30), # New prediction slider
                  width = 12
                )
              ),
              
              # Second row: KPI value boxes displaying key metrics
              fluidRow(
                valueBoxOutput("top_product", width = 3),
                valueBoxOutput("best_price", width = 3),
                valueBoxOutput("total_sales", width = 3),
                valueBoxOutput("total_units", width = 3)
              ),
              
              # Third row: Two plots side by side - Sales Distribution and Price Distribution
              fluidRow(
                box(
                  title = "Sales Distribution",
                  status = "primary",
                  solidHeader = TRUE,
                  girafeOutput("sales_plot", height = "300px"),
                  width = 6,
                  collapsible = TRUE
                ),
                box(
                  title = "Price Distribution",
                  status = "primary",
                  solidHeader = TRUE,
                  girafeOutput("price_distribution", height = "300px"),
                  width = 6,
                  collapsible = TRUE
                )
              ),
              
              # Fourth row: Two plots - Discount vs Sales Quantity and Sales Quantity vs Price
              fluidRow(
                box(
                  title = "Discount vs Sales Quantity",
                  status = "primary",
                  solidHeader = TRUE,
                  girafeOutput("discount_sales_chart", height = "400px"),
                  width = 6
                ),
                box(
                  title = "Sales Quantity vs Price",
                  status = "primary",
                  solidHeader = TRUE,
                  plotOutput("sales_vs_price_chart", height = "400px"),
                  width = 6
                )
              ),
              
              
              # Fifth row: Top 5 Products (Circular View) and Sales Forecast side by side
              fluidRow(
                # Top 5 Products by Units Sold (Circular View)
                box(
                  title = "Top 5 Products by Units Sold (Circular View)",  # Title for the new plot
                  status = "primary",  # Styling for the box
                  solidHeader = TRUE,  # Solid box header
                  plotOutput("top_5_products_plot", height = "400px"),  # Reference the new plot
                  width = 6,  # Adjust width (6 means half-width, 12 is full-width)
                  collapsible = TRUE  # Allow the box to be collapsible
                ),
                
                # Sales Forecast
                box(
                  title = "Sales Forecast",  # Title for the forecast plot
                  status = "warning",  # Styling for the box
                  solidHeader = TRUE,  # Solid box header
                  plotOutput("sales_forecast_plot", height = "400px"),  # Reference the forecast plot
                  width = 6,  # Adjust width (6 means half-width)
                  collapsible = TRUE  # Allow the box to be collapsible
                )
              ),
              
      ),
      
      # Data table tab layout
      tabItem(tabName = "datatable",
              fluidRow(
                dataTableOutput("filtered_data"),
                uiOutput("export_ui")  # Add export button here
              )
      )
    )
  )
)
