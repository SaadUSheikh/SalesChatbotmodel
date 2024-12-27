library(shiny)
library(ggplot2)

#shiny server
shinyServer(function(input, output) {
  
  # Helper function to truncate titles to the first 3 words
  truncate_title <- function(title) {
    words <- strsplit(title, " ")[[1]]
    if(length(words) > 3) {
      return(paste(paste(words[1:3], collapse = " "), "..."))
    } else {
      return(title)
    }
  }
  
  # Reactive expression to filter products based on selected categories and units sold out
  filtered_products <- reactive({
    data <- products_with_categories
    if (length(input$selected_category) > 0) {
      data <- data %>% filter(category_name %in% input$selected_category)
    }
    
    # Filter by units sold and arrange by descending units sold
    data <- data %>%
      filter(boughtInLastMonth >= input$units_sold[1] & boughtInLastMonth <= input$units_sold[2]) %>%
      arrange(desc(boughtInLastMonth)) %>%
      mutate(title = sapply(title, truncate_title))
    
    return(data)
  })
  
  # Output: Best Price (price and units for the product that maximizes total sales)
  output$best_price <- renderValueBox({
    if (nrow(filtered_products()) > 0) {
      best_product <- filtered_products()[which.max(filtered_products()$price * filtered_products()$boughtInLastMonth), ]
      best_price <- round(best_product$price, 2)
      best_qty <- best_product$boughtInLastMonth
      
      # Display the best price and quantity in the value box
      valueBox(
        paste0("$", prettyNum(best_price, big.mark = ","), " (Qty ", prettyNum(best_qty, big.mark = ","), ")"), 
        "Best Price", 
        icon = icon("dollar-sign"), 
        color = "green"
      )
    } else {
      valueBox("$0", "Best Price", icon = icon("dollar-sign"), color = "green")
    }
  })
  
  # Output: Top Product (Only First Word of the Title) meri ghand and bund
  output$top_product <- renderValueBox({
    if (nrow(filtered_products()) > 0) {
      top_product <- filtered_products()[which.max(filtered_products()$boughtInLastMonth), "title"]
      
      top_product_one_word <- strsplit(top_product, " ")[[1]][1]
      
      valueBox(top_product_one_word, "Top Product", icon = icon("trophy"), color = "yellow")
    } else {
      valueBox("No data", "Top Product", icon = icon("trophy"), color = "yellow")
    }
  })
  
  # Output: Total Sales
  output$total_sales <- renderValueBox({
    if (nrow(filtered_products()) > 0) {
      total_sales <- sum(filtered_products()$price * filtered_products()$boughtInLastMonth)
      valueBox(
        paste0("$", prettyNum(round(total_sales, 2), big.mark = ",")),  
        "Total Sales", 
        icon = icon("chart-line"), 
        color = "blue"
      )
    } else {
      valueBox("$0", "Total Sales", icon = icon("chart-line"), color = "blue")
    }
  })
  
  # Output: Total Units Sold
  output$total_units <- renderValueBox({
    if (nrow(filtered_products()) > 0) {
      total_units <- sum(filtered_products()$boughtInLastMonth)
      valueBox(
        prettyNum(total_units, big.mark = ","),  
        "Total Units Sold", 
        icon = icon("shopping-cart"), 
        color = "purple"
      )
    } else {
      valueBox(0, "Total Units Sold", icon = icon("shopping-cart"), color = "purple")
    }
  })
  
  # Sales Distribution Plot (Top 15 Products with First 3 Words in Title) with Interactivity
  output$sales_plot <- renderGirafe({
    if (nrow(filtered_products()) > 0) {
      top_15_products <- filtered_products() %>%
        head(15) %>%
        mutate(title = sapply(title, truncate_title))  
      
      # Escape single quotes in the title
      top_15_products$title <- gsub("'", "&#39;", top_15_products$title)
      
      # Create bar chart for sales distribution
      p <- ggplot(top_15_products, aes(x = reorder(title, boughtInLastMonth), y = boughtInLastMonth)) +
        geom_bar_interactive(
          aes(
            tooltip = paste("Product:", title, "<br>Units Sold:", boughtInLastMonth),
            data_id = title,
            fill = title  
          ),
          stat = "identity"
        ) +
        scale_fill_brewer(palette = "Set3") +  
        coord_flip() +
        labs(
          title = "Top 15 Products in Selected Categories",
          x = "Product",
          y = "Units Sold Last Month"
        ) +
        theme_minimal() +
        theme(axis.text.x = element_text(angle = 45, hjust = 1))
      
      # Render interactive plot using girafe
      girafe(ggobj = p, width_svg = 8, height_svg = 5)
    } else {
      girafe(ggobj = ggplot() + labs(title = "No data to display"))
    }
  })
  
  
  
  # Price Distribution Plot
  output$price_distribution <- renderGirafe({
    if (nrow(filtered_products()) > 0) {
      top_15_products <- filtered_products() %>%
        head(15) %>%
        mutate(title = sapply(title, truncate_title))  
      
      # Escape single quotes in the title
      top_15_products$title <- gsub("'", "&#39;", top_15_products$title)
      
      # Create bar chart for price distribution
      p <- ggplot(top_15_products, aes(x = reorder(title, price), y = price)) +
        geom_bar_interactive(
          aes(
            tooltip = paste("Product:", title, "<br>Price: $", price),
            data_id = title,
            fill = price  
          ),
          stat = "identity"
        ) +
        labs(
          title = "Price Distribution Across Top 15 Products",
          x = "Product",
          y = "Price"
        ) +
        scale_fill_viridis_c(option = "D") +  
        theme_minimal() +
        theme(axis.text.x = element_text(angle = 90, hjust = 1))
      
      # Render interactive plot using girafe
      girafe(ggobj = p, width_svg = 8, height_svg = 5)
    } else {
      girafe(ggobj = ggplot() + labs(title = "No data to display"))
    }
  })
  
  
  # Discount vs Sales Chart
  output$discount_sales_chart <- renderGirafe({
    # Filtered data based on user selections
    data <- filtered_products()
    
    # Calculate Discount (ListPrice - Price) for filtered data
    data$Discount <- data$listPrice - data$price
    
    # Filter to include only rows where Discount is positive and Sales Quantity is greater than a threshold
    valid_data <- data %>%
      filter(!is.na(Discount) & !is.na(boughtInLastMonth) & Discount > 0 & boughtInLastMonth > 5000)
    
    # Escape single quotes in the title to avoid errors in tooltips
    valid_data$title <- gsub("'", "", valid_data$title)
    
    # Create the interactive plot with a color gradient based on Discount
    p <- ggplot(valid_data, aes(x = Discount, y = boughtInLastMonth)) +
      geom_point_interactive(
        aes(
          tooltip = paste("Product:", title, "<br>Discount:", Discount, "<br>Sales Qty:", boughtInLastMonth),
          data_id = title,
          color = Discount  # Use Discount as a basis for the color gradient
        ),
        size = 3
      ) +
      labs(
        title = "Discount vs Sales Quantity (When: Sales > 5000)",
        x = "Discount (List Price - Actual Price)",
        y = "Sales Quantity (Units Bought Last Month)"
      ) +
      scale_x_continuous(breaks = seq(0, 30, by = 5)) +  # X-axis breaks
      scale_y_continuous(breaks = seq(20000, 100000, by = 20000), labels = scales::comma) +  # Y-axis breaks
      scale_color_viridis_c(option = "D") +  # Use a colorful viridis color palette
      theme_minimal()
    
    # Render the interactive ggplot using girafe
    girafe(ggobj = p, width_svg = 8, height_svg = 5)
  })
  
  # Sales Quantity vs Price Plot
  output$sales_vs_price_chart <- renderPlot({
    # Use filtered products data based on user selections
    data <- filtered_products()
    
    # Filter to include only rows where price and sales quantity are valid
    valid_data <- data[!is.na(data$price) & data$price > 0 & data$boughtInLastMonth > 0, ]
    
    # Create the scatter plot of Sales Quantity (BoughtInLastMonth) vs Price
    ggplot(valid_data, aes(x = price, y = boughtInLastMonth)) +
      geom_point(color = "green", size = 3) +
      labs(
        title = "Sales Quantity vs Price",
        x = "Price",
        y = "Sales Quantity (Units Bought Last Month)"
      ) +
      scale_x_continuous(labels = scales::dollar_format()) +  # Format the x-axis (Price) with currency
      scale_y_continuous(labels = scales::comma) +  # Format the y-axis (Sales Quantity) with commas
      theme_minimal()
  })
  
  
  # Top 5 Products in Circular Layout with Enhanced Colors and Title Limitation
  output$top_5_products_plot <- renderPlot({
    # Use filtered products data based on user selections
    data <- filtered_products()
    
    # Helper function to return only the first 3 words of the title
    limit_to_three_words <- function(title) {
      words <- strsplit(title, " ")[[1]]
      return(paste(words[1:min(2, length(words))], collapse = " "))  # Limit to 2 words
    }
    
    # Select top 5 products based on units sold last month and limit titles to 2 words
    top_5_products <- data %>%
      arrange(desc(boughtInLastMonth)) %>%
      head(5) %>%
      mutate(Product = sapply(title, limit_to_three_words))  # Limit title to 2 words
    
    # Define a vibrant color palette for the circles
    color_palette <- c("#FF5733", "#33FF57", "#3357FF", "#F333FF", "#33FFF3")
    
    # Create circular layout using geom_point for colorful circles
    ggplot(top_5_products, aes(x = factor(Product), y = boughtInLastMonth)) +
      geom_point(aes(size = boughtInLastMonth, fill = factor(Product)), 
                 shape = 21, color = "black", stroke = 1.5) +  # Add vibrant fill colors and black outline
      scale_fill_manual(values = color_palette) +  # Apply the custom color palette
      geom_text(aes(label = boughtInLastMonth), 
                vjust = -1, size = 5, color = "black", fontface = "bold") +  # Adjust label size and position for clarity
      labs(title = "Top 5 Products by Units Sold", x = "Product", y = "Units Sold") +
      theme_minimal() +
      theme(
        axis.text.x = element_text(size = 12, face = "bold", angle = 90, hjust = 1, color = "black"),  # Style product title for better readability
        plot.title = element_text(hjust = 0.5, size = 16, face = "bold", color = "#003366"),  # Center and style the title with dark blue color
        axis.title.y = element_text(size = 12, face = "bold", color = "#003366"),  # Style Y-axis label
        axis.title.x = element_text(size = 12, face = "bold", color = "#003366"),  # Style X-axis label
        panel.grid = element_blank(),  # Remove all grid lines for a cleaner look
        panel.background = element_rect(fill = "white", color = NA)  # Set a white background
      ) +
      guides(size = guide_legend("Units Sold"))  # Rename the legend to make it clearer
  })
  
  
  
  
# Sales Forecast based on the number of days ahead selected in the slider
output$sales_forecast_plot <- renderPlot({
  if (nrow(filtered_products()) > 0) {
    # Use the forecasting logic to predict future sales
    data_ts <- ts(filtered_products()$boughtInLastMonth)
    
    # Get the user-selected value or use the default value
    n_ahead <- input$prediction_days  # Use the value directly from the slider (now max 60 days)
    
    # Simplified ETS forecast (exponential smoothing)
    pred <- forecast::ets(data_ts)
    future_sales <- forecast::forecast(pred, h = n_ahead)  # h is set based on the slider's value
    
    # Plot the forecasted sales with x-axis limited to the user-selected value
    autoplot(future_sales) + 
      ggtitle(paste("Sales Forecast for Next", n_ahead, "Days")) +
      xlab("Days") + ylab("Sales") +
      scale_x_continuous(limits = c(0, n_ahead))  # Set the x-axis limits based on user-selected value
  } else {
    plot.new()
    text(0.5, 0.5, "No data to forecast", cex = 1.5)
  }
})


# Data Table
output$filtered_data <- renderDataTable({
  if (nrow(filtered_products()) > 0) {
    datatable(
      filtered_products() %>%
        select(title, stars, reviews, price, listPrice, boughtInLastMonth),
      options = list(pageLength = input$num_records)
    )
  } else {
    datatable(data.frame(message = "No data available"))
  }
})

# Download data as CSV
output$download_filtered_data <- downloadHandler(
  filename = function() {
    paste("filtered_data-", Sys.Date(), ".csv", sep = "")
  },
  content = function(file) {
    if (nrow(filtered_products()) > 0) {
      write.csv(filtered_products() %>%
                  select(title, stars, reviews, price, listPrice, boughtInLastMonth), file, row.names = FALSE)
    } else {
      write.csv(data.frame(message = "No data available"), file, row.names = FALSE)
    }
  }
)

# Export button
output$export_ui <- renderUI({
  downloadButton("download_filtered_data", "Download Data")
})



})
