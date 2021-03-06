Exploring NOAA Storm Data (1950-2011)
========================================================
author: Darwin Gosal
date: 27 September 2015

Introduction
========================================================

U.S. National Oceanic and Atmospheric Administration's (NOAA) storm (and other severe weather events) [database](http://d396qusza40orc.cloudfront.net/repdata%2Fdata%2FStormData.csv.bz2) record public health (i.e. fatalities and injuries) and economic impact (i.e. property and crop damage) for communities and municipalities across United States of America.


Analysis
========================================================

In our [analysis](https://rpubs.com/gosaldar/82046), we have identified that:

- Tornado caused the most harm to public health
- Flood caused the greatest economy impact


Application
========================================================

Using the **shiny** package, I have develop an [interactive application](https://gosaldar.shinyapps.io/data-product-project) for reader to explore the dataset:

User can change or select the following parameters:
- the type of weather events
- the range of the years

The result can will shown either **by state** or **by year**.


Data
========================================================
The original data has been transformed into a format where it can be used easily for the application. Below is an example of my data.

```r
library(data.table)
dt <- fread('data/events.csv')
head(dt,2)
```

```
   YEAR   STATE  EVTYPE COUNT FATALITIES INJURIES PROPDMG CROPDMG
1: 1950 alabama TORNADO     2          0       15  0.0275       0
2: 1951 alabama TORNADO     5          0       13  0.0350       0
```


Source Code
========================================================

The source-code of the application and this presentation can be found in my [Github repository](https://github.com/gosaldar/data-product-project)
