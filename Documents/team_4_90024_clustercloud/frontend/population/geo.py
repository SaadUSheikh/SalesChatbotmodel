import json
import folium

with open('population_greater_melbourne.json') as f:
    data = json.load(f)

m = folium.Map([-37.8, 145.0], zoom_start=9)

for d in data:
    a = folium.GeoJson(d["geometry"]).add_to(m)

m.save("map.html")