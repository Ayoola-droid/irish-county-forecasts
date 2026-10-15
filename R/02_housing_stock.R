# Estimate and forecast housing stock by county
# =============================================
# Rebuilds yearly housing stock from census counts and new-house registrations, then forecasts 2023-2025.
# Part of: How Crime Shapes Property Values (MSc Business Analytics thesis, Ayoola Fadare, 2025)
# Inputs: data/housing stock.csv, data/new house reg*.csv

# HOUSING STOCK -----------------------------------------------------------

skim(housing)

housing %>% 
    distinct(UNIT) %>% 
    view()

housing %>% 
    filter(UNIT ==  "%" & !is.na(VALUE)) %>% 
    view()

# pivot wider
housing <- housing %>%
    filter(`Type of Private Household` == "All households" &
               `Housing Stock`         == "Total housing stock" &
               UNIT                    == "Number" &
               `Statistic Label`       == "Housing stock") %>%
    # view()
    select(CensusYear, `County and City`, `Housing Stock`, VALUE) %>%
    pivot_wider(
        id_cols = c(CensusYear, `County and City`),
        names_from = `Housing Stock`,
        values_from = VALUE
    )


# Address the housing stock dataset
housing <- housing %>% 
    mutate(county = word(`County and City`, 1))
# replace Dun And South with dublin
housing <- housing %>% 
    mutate(
        county = if_else(county %in% c("Dún", "South", "Fingal"), "Dublin", county)
    )
housing <- housing %>%
    group_by(county,CensusYear) %>%
    summarise(`Total housing stock` = sum(`Total housing stock`, na.rm = TRUE), .groups = "drop")

# summ all new house regigistration to get the total of all new housing
skim(new_house_reg)

new_house_reg <- new_house_reg %>%
    arrange(County, Year) %>%
    group_by(County) %>%
    mutate(sum_reg = cumsum(VALUE))

new_house_reg2 <- new_house_reg2 %>% 
    # split "1994Q1" into Year = "1994" and Q = "1"
    separate(Quarter,
             into    = c("Year", "Q"),
             sep     = "Q",
             convert = TRUE) %>%
    # if you want your quarter back as "Q1" etc
    mutate(Quarter = paste0("Q", Q)) %>%
    select(-Q)

new_house_reg2 %>% 
    filter(is.na(VALUE)) %>% 
    View()

annual_by_county <- new_house_reg2 %>%
    group_by(County, Year) %>% 
    summarise(total_reg = sum(VALUE), .groups = "drop")

new_house_reg <- new_house_reg %>% 
    select(County,Year,VALUE) %>% 
    filter(Year < 1994)

new_house <- bind_rows(
    annual_by_county,
    new_house_reg) %>%
    # remove any exact duplicates if needed
    distinct(County, Year, .keep_all = TRUE) %>%
    arrange(County, Year)

new_house <- new_house %>% 
    mutate(reg_no = coalesce(VALUE,total_reg)) %>% 
    select(-VALUE,-total_reg)
# rename all counties as state
new_house <- new_house %>% 
    mutate(
        County = if_else(County == "All Counties", "State", County)
    )

new_house_est <- new_house %>%
    # make a row for every year 2010–2025 in each county
    group_by(County) %>%
    complete(Year = 2023:2025) %>%
    arrange(County, Year) %>%
    # fill VALUE by linear interpolation/extrapolation
    mutate(
        VALUE = approx(
            x    = Year[!is.na(reg_no)],
            y    = reg_no[!is.na(reg_no)],
            xout = Year,
            rule = 2
        )$y
    ) %>%
    ungroup()
# to get the housing stock ofr the years 2010 - 2025 SUBTRACT the number of new regeistrations
# in 2022 FROM the number of Total stock in 2022 to get 2021 stock
# Tidy up the housing stock table
housing <- housing %>%
    rename(
        County = `county`,
        Year   = CensusYear,
        Stock  = `Total housing stock`
    )
stock <- new_house %>%
    rename(County = County) %>%   # just to be explicit
    full_join(housing, by = c("County", "Year")) %>%
    arrange(County, Year)

skim(stock)
stock <- stock %>%
    arrange(County, Year) %>%
    group_by(County) %>%
    group_modify(~ {
        dat <- .x
        yrs <- dat$Year
        regs <- dat$reg_no
        n    <- nrow(dat)
        
        # find indexes
        i2016 <- which(yrs == 2016)
        i2022 <- which(yrs == 2022)
        
        # prepare two result vectors
        st16 <- rep(NA_real_, n)
        st22 <- rep(NA_real_, n)
        
        # seed known stocks
        st16[i2016] <- dat$Stock[i2016]
        st22[i2022] <- dat$Stock[i2022]
        
        # backward & forward for 2016-based
        # backward from 2016
        if (i2016 > 1) {
            for (i in (i2016 - 1):1) {
                st16[i] <- st16[i + 1] - regs[i + 1]
            }
        }
        # forward from 2016
        if (i2016 < n) {
            for (i in (i2016 + 1):n) {
                st16[i] <- st16[i - 1] + regs[i - 1]
            }
        }
        
        # backward & forward for 2022-based
        # backward from 2022
        if (i2022 > 1) {
            for (i in (i2022 - 1):1) {
                st22[i] <- st22[i + 1] - regs[i + 1]
            }
        }
        # forward from 2022
        if (i2022 < n) {
            for (i in (i2022 + 1):n) {
                st22[i] <- st22[i - 1] + regs[i - 1]
            }
        }
        
        # combine into final df
        dat %>%
            mutate(
                stock_from_2016 = st16,
                stock_from_2022 = st22,
                stock_estimate  = (st16 + st22) / 2
            )
    }) %>%
    ungroup()

stock <- stock %>% 
    select(County,Year,stock_estimate) %>% 
    mutate(Census_yr = as.Date(paste0(Year, "-01-01")),
           Year      = year(Census_yr)) %>%
    rename(estimate  = stock_estimate) %>% 
    select(County,Census_yr,estimate,Year) %>% 
    arrange(Census_yr)    # make sure it's sorted by date



# forecast values for the upcoming years of 23, 24 and 25
fit_and_evaluate <- function(df) {
    df <- as_tibble(df)
    if (nrow(df) < 6) return(tibble())
    
    splits_pop <- initial_time_split(df, prop = 0.8)
    train_pop  <- training(splits_pop)
    test_pop   <- testing(splits_pop)
    
    rec_pop <- recipe(estimate ~ Census_yr, 
                      data = train_pop) %>%
        step_impute_median(all_numeric(), -all_outcomes()) %>%
        step_dummy(all_nominal_predictors()) %>% 
        step_normalize() 
    
    model_funs <- list(
        # ARIMA
        arima = arima_reg() %>% 
            set_engine("auto_arima") %>% 
            set_mode("regression"),
        #ETS (Exponential Smoothing) 
        ets   = exp_smoothing() %>% 
            set_engine("ets") %>% 
            set_mode("regression"),
        
        tbats = seasonal_reg() %>% 
            set_engine("tbats") %>% 
            set_mode("regression"),
        # Neural net time series
        nn    = nnetar_reg() %>% 
            set_engine("nnetar") %>% 
            set_mode("regression")
    )
    
    results <- map_dfr(names(model_funs), function(name) {
        wf_pop <- workflow() %>%
            add_model(model_funs[[name]]) %>%
            add_recipe(rec_pop)
        
        fit_model <- fit(wf_pop, data = train_pop)
        
        preds <- predict(fit_model, new_data = test_pop) %>%
            bind_cols(test_pop %>% select(estimate))
        
        acc <- metrics(preds, truth = estimate, estimate = .pred) %>%
            mutate(model = name)
        
        return(acc)
    })
    
    return(results)
}
results_stk <- stock %>%
    filter(County != "State") %>% 
    group_by(County) %>%
    nest() %>% 
    mutate(metrics = map(data, fit_and_evaluate)) %>%
    select(County, metrics) %>%
    unnest(metrics)

# modelling to predict the next three years
model_funs <- list(
    arima = arima_reg() %>% set_engine("auto_arima")  %>% set_mode("regression"),
    ets   = exp_smoothing() %>% set_engine("ets")     %>% set_mode("regression"),
    tbats = seasonal_reg()  %>% set_engine("tbats")   %>% set_mode("regression"),
    nn    = nnetar_reg()    %>% set_engine("nnetar")  %>% set_mode("regression")
)

# for each county, make a 3-year future tibble and predict
forecasts_stk <- stock %>%
    filter(County != "State") %>% 
    group_by(County) %>%
    nest() %>%
    mutate(
        # build a little tibble of the next 3 Census years
        future = map(data, ~ {
            last_date <- max(.x$Census_yr)
            tibble(
                Census_yr = seq.Date(from = last_date,
                                     by   = "1 year",
                                     length.out = 4)[-1]
            )
        }),
        # for each model, fit on ALL the data and predict on those 3 years
        forecasts = map2(data, future, ~ {
            map_dfr(names(model_funs), function(mname) {
                # recipe + workflow
                rec <- recipe(estimate ~ Census_yr, data = .x) %>%
                    step_impute_median(all_numeric(), -all_outcomes()) %>%
                    step_dummy(all_nominal_predictors()) %>%
                    step_normalize()
                wf <- workflow() %>%
                    add_model(model_funs[[mname]]) %>%
                    add_recipe(rec)
                # fit on full history
                fit_full <- fit(wf, data = .x)
                # predict the 3 future years
                preds <- predict(fit_full, new_data = .y)
                bind_cols(.y, preds) %>%
                    mutate(model = mname)
            })
        })
    ) %>%
    select(County, forecasts) %>%
    unnest(forecasts)

# best model for prediction
best_models_stk <- results_stk %>%
    filter(.metric == "rmse") %>%
    group_by(County) %>%
    slice_min(.estimate, n = 1) %>%
    ungroup() %>% 
    select(County, best_model = model)

# join the best model forecast for each county
best_forecasts_stk <- forecasts_stk %>%
    left_join(best_models_stk, by = "County") %>%
    filter(model == best_model) %>%
    arrange(County, Census_yr) %>%
    select(County, Census_yr, forecast = .pred)

# add the forecasted data to the population data
best_forecasts_stk <- best_forecasts_stk %>% 
    mutate(Year = year(Census_yr)) %>% 
    rename(estimate = forecast )

stock <- stock %>% 
    rows_append(best_forecasts_stk)

# join into the property dataset
detail_prop <- detail_prop %>% 
    left_join(stock, by = c("County", "Year"))

skim(detail_prop)

detail_prop <- detail_prop %>%
    rename(House_stk = estimate)

detail_prop <- detail_prop %>% 
    select(-Census_yr)


    
skim(house_stk)

