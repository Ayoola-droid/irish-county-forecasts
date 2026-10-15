# County-Level Forecasts: Income, Population and Housing Stock in Ireland

**R · tidymodels · modeltime (ARIMA, ETS, neural-network autoregression)**

Census data only arrives every few years, but my house-price model needed yearly county figures up to 2025. This project fills the gaps between censuses and forecasts beyond the last one, choosing the best model separately for each of Ireland's 26 counties.

## Business question

What were each county's median income, population and housing stock in every year from 2010 to 2025, when official figures exist only for census years?

## Approach

1. **Interpolate** between census years (linear) to get a yearly series per county.
2. **Rebuild housing stock** year by year: start from the 2016 and 2022 census counts and add or subtract new-house registrations going forwards and backwards.
3. **Forecast** the years after the last census with three models per county:
    - ARIMA
    - Exponential smoothing (ETS)
    - Neural-network autoregression (NNETAR)
4. **Pick the best model per county** on accuracy, refit on all history, and forecast.
5. **Join** the estimates to each property sale by county and year, for use in the [house prices and crime model](https://github.com/Ayoola-droid/irish-house-prices-crime).

## Results

[Add one chart, e.g. forecast vs actual for Dublin and Leitrim, and a table of which model won in how many counties.] <!-- fill in -->

## Files

```
R/
├── 00_setup.R
├── 01_median_income.R
├── 02_housing_stock.R
└── 03_population.R
data/
├── median income.csv, median income 2010.csv   # CSO
├── population at census.csv                     # CSO F1001
├── housing stock.csv                            # CSO F2020
├── new house reg.csv, new house reg2.csv        # CSO HSQ10
└── county_size.csv
```

All input data is included, so these scripts can be run on their own (the final join step needs the property data from the main project).

## Skills demonstrated

Time-series forecasting · Model comparison and selection · Interpolation · Working with official statistics (CSO) · R / tidymodels

## Author

Ayoola Fadare · MSc Business Analytics (2025)
