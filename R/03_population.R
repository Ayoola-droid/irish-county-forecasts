# Estimate and forecast population by county
# ==========================================
# Interpolates population between censuses and forecasts 2023-2025 with the same model comparison.
# Part of: How Crime Shapes Property Values (MSc Business Analytics thesis, Ayoola Fadare, 2025)
# Inputs: data/population at census.csv

# population --------------------------------------------------------------
# CREATE population estimates for year 2010 TO 2025
population_ireland <- population_ireland %>% 
    filter(Sex == "Both sexes")

pop_estimate <- population_ireland %>%
    # pick county, year, value
    distinct(County, CensusYear, VALUE) %>%
    # make a row for every year 2010–2025 in each county
    group_by(County) %>%
    complete(CensusYear = 2010:2022) %>%
    arrange(County, CensusYear) %>%
    # fill VALUE by linear interpolation/extrapolation
    mutate(
        VALUE = approx(
            x    = CensusYear[!is.na(VALUE)],
            y    = VALUE[!is.na(VALUE)],
            xout = CensusYear,
            rule = 2
        )$y
    ) %>%
    ungroup()

 

pop_estimate %>% 
    filter(CensusYear >= 2010) %>% 
    View()
    
skim(pop_estimate)



pop_estimate <- pop_estimate %>% 
    select(County,CensusYear,VALUE) %>% 
    mutate(Census_yr = as.Date(paste0(CensusYear, "-01-01")),
           Year      = year(Census_yr)) %>%
    rename(estimate  = VALUE) %>% 
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
results_pop <- pop_estimate %>%
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
forecasts_pop <- pop_estimate %>%
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
best_models <- results_pop %>%
    filter(.metric == "rmse") %>%
    group_by(County) %>%
    slice_min(.estimate, n = 1) %>%
    ungroup() %>% 
    select(County, best_model = model)

# join the best model forecast for each county
best_forecasts <- forecasts_pop %>%
    left_join(best_models, by = "County") %>%
    filter(model == best_model) %>%
    arrange(County, Census_yr) %>%
    select(County, Census_yr, forecast = .pred)

# add the forecasted data to the population data
best_forecasts <- best_forecasts %>% 
    mutate(Year = year(Census_yr)) %>% 
    rename(estimate = forecast )

pop_estimate <- pop_estimate %>% 
    rows_append(best_forecasts)

best_models %>% 
    count(model)

# join into the property dataset
detail_prop <- detail_prop %>% 
    left_join(pop_estimate, by = c("County", "Year"))

skim(detail_prop)

detail_prop <- detail_prop %>%
    rename(Pop_est = estimate)

detail_prop <- detail_prop %>% 
    select(-Census_yr)



