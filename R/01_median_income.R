# Forecast median income by county
# ================================
# Interpolates census-year median income and compares ARIMA, ETS and neural-network forecasts per county, keeping the best model.
# Part of: How Crime Shapes Property Values (MSc Business Analytics thesis, Ayoola Fadare, 2025)
# Inputs: data/median income.csv, data/median income 2010.csv

# Median Income -----------------------------------------------------------
income <- income %>%
    filter(`Statistic Label` == "Median Annual Earnings",
           Sex               == "Both sexes",
           County            != "All counties (1)") %>%
    select(County,Year,VALUE)

income10 <- income10 %>% 
    rename(VALUE = value,
           Year  = year)
# join 2010 data with the others
income <- income %>% 
    rows_append(income10)

income <- income %>% 
    rename(CensusYear = Year)

detail_prop %>% 
    distinct(County) %>% 
    view()

# predict median income for each county for 24 and 25
income <- income %>% 
    select(County,CensusYear,VALUE) %>% 
    mutate(Census_yr = as.Date(paste0(CensusYear, "-01-01")),
           Year      = year(Census_yr)) %>%
    rename(estimate  = VALUE) %>% 
    select(County,Census_yr,estimate,Year) %>% 
    arrange(Census_yr)    # make sure it's sorted by date





# forecast values for the upcoming years of 24 and 25
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
results_inc <- income %>%
    group_by(County) %>%
    nest() %>% 
    mutate(metrics = map(data, fit_and_evaluate)) %>%
    select(County, metrics) %>%
    unnest(metrics)

# modelling to predict the next two years
model_funs <- list(
    arima = arima_reg() %>% set_engine("auto_arima")  %>% set_mode("regression"),
    ets   = exp_smoothing() %>% set_engine("ets")     %>% set_mode("regression"),
    tbats = seasonal_reg()  %>% set_engine("tbats")   %>% set_mode("regression"),
    nn    = nnetar_reg()    %>% set_engine("nnetar")  %>% set_mode("regression")
)

# for each county, make a 2-year future tibble and predict
forecasts_inc <- income %>%
    group_by(County) %>%
    nest() %>%
    mutate(
        # build a little tibble of the next 2 Census years
        future = map(data, ~ {
            last_date <- max(.x$Census_yr)
            tibble(
                Census_yr = seq.Date(from = last_date,
                                     by   = "1 year",
                                     length.out = 3)[-1]
            )
        }),
        # for each model, fit on ALL the data and predict on those 2 years
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
best_models <- results_inc %>%
    filter(.metric == "rmse") %>%
    group_by(County) %>%
    slice_min(.estimate, n = 1) %>%
    ungroup() %>% 
    select(County, best_model = model)

# join the best model forecast for each county
best_forecasts <- forecasts_inc %>%
    left_join(best_models, by = "County") %>%
    filter(model == best_model) %>%
    arrange(County, Census_yr) %>%
    select(County, Census_yr, forecast = .pred)

# add the forecasted data to the population data
best_forecasts <- best_forecasts %>% 
    mutate(Year = year(Census_yr)) %>% 
    rename(estimate = forecast )

income <- income %>% 
    rows_append(best_forecasts)

# join into property data
# join into the property dataset
detail_prop <- detail_prop %>% 
    left_join(income, by = c("County", "Year"))

skim(detail_prop)

detail_prop <- detail_prop %>%
    rename(median_income = estimate)

detail_prop <- detail_prop %>% 
    select(-Census_yr)

