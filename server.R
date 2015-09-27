library(shiny)

## Libraries needed for plotting, data processing and maps
library(ggplot2)
library(ggvis)
library(rCharts)
library(data.table)
library(dplyr)
library(reshape2)
library(markdown)
library(maps)
library(mapproj)

## Create helper functions

round2 <- function(x) round(x, 2)
replace_na <- function(x) ifelse(is.na(x), 0, x)

aggregate_by_year <- function(dt, year_min, year_max, evtypes) {
  dt %>% filter(YEAR >= year_min, YEAR <= year_max, EVTYPE %in% evtypes) %>%
    group_by(YEAR) %>% summarise_each(funs(sum), COUNT:CROPDMG) %>%
    mutate_each(funs(round2), PROPDMG, CROPDMG) %>%
    rename(
      Year = YEAR, Count = COUNT,
      Fatalities = FATALITIES, Injuries = INJURIES,
      Property = PROPDMG, Crops = CROPDMG
    )
}

aggregate_by_state <- function(dt, year_min, year_max, evtypes) {
  states <- data.table(STATE=sort(unique(dt$STATE)))
    aggregated <- dt %>% filter(YEAR >= year_min, YEAR <= year_max, EVTYPE %in% evtypes) %>%
    group_by(STATE) %>%
    summarise_each(funs(sum), COUNT:CROPDMG)
  
  left_join(states,  aggregated, by = "STATE") %>%
    mutate_each(funs(replace_na), FATALITIES:CROPDMG) %>%
    mutate_each(funs(round2), PROPDMG, CROPDMG)    
}

compute_damages <- function(dt, category) {
  dt %>% mutate(Damages = {
    if(category == 'both') {
      PROPDMG + CROPDMG
    } else if(category == 'property') {
      PROPDMG
    } else {
      CROPDMG
    }
  })
}

compute_affected <- function(dt, category) {
  dt %>% mutate(Affected = {
    if(category == 'both') {
      INJURIES + FATALITIES
    } else if(category == 'injuries') {
      INJURIES
    } else {
      FATALITIES
    }
  })
}

plot_impact_by_state <- function (dt, states_map, year_min, year_max, fill, title, low = "#fef4ea", high = "#d84701") {
  title <- sprintf(title, year_min, year_max)
  p <- ggplot(dt, aes(map_id = STATE))
  p <- p + geom_map(aes_string(fill = fill), map = states_map, colour='black')
  p <- p + expand_limits(x = states_map$long, y = states_map$lat)
  p <- p + coord_map() + theme_bw()
  p <- p + labs(x = "Longitude", y = "Latitude", title = title)
  p + scale_fill_gradient(low = low, high = high)
}

plot_impact_by_year <- function(dt, dom, yAxisLabel, desc = FALSE) {
  impactPlot <- nPlot(
    value ~ Year, group = "variable",
    data = melt(dt, id="Year") %>% arrange(Year, if (desc) { desc(variable) } else { variable }),
    type = "stackedAreaChart", dom = dom, width = 650
  )
  impactPlot$chart(margin = list(left = 100))
  impactPlot$xAxis(axisLabel = "Year", width = 70)
  impactPlot$yAxis(tickFormat = "#! function(d) {return d3.format(',0f')(d)} !#", axisLabel = yAxisLabel, width = 80)
  impactPlot
}

plot_events_by_year <- function(dt, dom = "eventsByYear", yAxisLabel = "Count") {
  eventsByYear <- nPlot(
    Count ~ Year,
    data = dt,
    type = "lineChart", dom = dom, width = 650
  )
  eventsByYear$chart(margin = list(left = 100))
  eventsByYear$xAxis(axisLabel = "Year", width = 70)
  eventsByYear$yAxis(tickFormat = "#! function(d) {return d3.format('n')(d)} !#", axisLabel = yAxisLabel, width = 80)
  eventsByYear
}

downloads <- function(dt) {
  dt %>% rename(
    State = STATE, Count = COUNT,
    Injuries = INJURIES, Fatalities = FATALITIES,
    Property.damage = PROPDMG, Crops.damage = CROPDMG
  ) %>% mutate(State=state.abb[match(State, tolower(state.name))])
}



## Load event and map data
dt <- fread('data/events.csv') %>% mutate(EVTYPE = tolower(EVTYPE))
evtypes <- sort(unique(dt$EVTYPE))
states_map <- map_data("state")


## Shiny server 
shinyServer(function(input, output, session) {
    
    values <- reactiveValues()
    values$evtypes <- evtypes
    
    output$evtypeControls <- renderUI({
        checkboxGroupInput('evtypes', 'Event types', evtypes, selected=values$evtypes)
    })
    
    observe({
        if(input$clear_all == 0) return()
        values$evtypes <- c()
    })
    
    observe({
        if(input$select_all == 0) return()
        values$evtypes <- evtypes
    })

    # Datasets preparation
    dt.agg <- reactive({
        aggregate_by_state(dt, input$range[1], input$range[2], input$evtypes)
    })
    
    dt.agg.year <- reactive({
        aggregate_by_year(dt, input$range[1], input$range[2], input$evtypes)
    })
    
    dataTable <- reactive({
        downloads(dt.agg())
    })
    
    # Events by year
    output$eventsByYear <- renderChart({
      plot_events_by_year(dt.agg.year())
    })
    
    # Population impact by year
    output$populationImpact <- renderChart({
      plot_impact_by_year(
        dt = dt.agg.year() %>% select(Year, Injuries, Fatalities),
        dom = "populationImpact",
        yAxisLabel = "Affected",
        desc = TRUE
      )
    })
    
    # Population impact by state
    output$populationImpactByState <- renderPlot({
      print(plot_impact_by_state (
        dt = compute_affected(dt.agg(), input$populationCategory),
        states_map = states_map, 
        year_min = input$range[1],
        year_max = input$range[2],
        title = "Population Impact %d - %d (People Affected)",
        fill = "Affected"
      ))
    })
    
    # Economic impact by state
    output$economicImpact <- renderChart({
      plot_impact_by_year(
        dt = dt.agg.year() %>% select(Year, Crops, Property),
        dom = "economicImpact",
        yAxisLabel = "Total Damage (Million US$)"
      )
    })

    # Economic impact by state
    output$economicImpactByState <- renderPlot({
        print(plot_impact_by_state(
            dt = compute_damages(dt.agg(), input$economicCategory),
            states_map = states_map, 
            year_min = input$range[1],
            year_max = input$range[2],
            title = "Economic Impact %d - %d (Million US$)",
            fill = "Damages"
        ))
    })
    
    
    # Render data table and create download handler
    output$table <- renderDataTable(
        {dataTable()}, options = list(searching = TRUE, pageLength = 10))
    
    output$downloadData <- downloadHandler(
        filename = 'stormdata.csv',
        content = function(file) {
            write.csv(dataTable(), file, row.names=FALSE)
        }
    )
})


