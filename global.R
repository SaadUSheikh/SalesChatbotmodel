
# Load necessary libraries
# Load necessary libraries
library(shiny)
library(ggplot2)
library(dplyr)
library(DT)  # For DataTables
library(RColorBrewer)
library(plotly)
library(ggiraph)



# Load datasets
setwd(dirname(rstudioapi::getActiveDocumentContext()$path))
amazon_categories <- read.csv("amazon_categories.csv")
aws_products <- read.csv("amazon_products.csv")

# Merge datasets on category_id
products_with_categories <- merge(aws_products, amazon_categories, by.x = "category_id", by.y = "id")

# Create a list of unique categories for dropdown selection
categories <- unique(products_with_categories$category_name)
