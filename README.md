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

	H1: TotalCrime	H2: Violent vs NonViolent	H3: PersonalSafety vs Property	H4: HighIncome*TotalCrime	H5: Crime Lags
+ p < 0.1, * p < 0.05, ** p < 0.01, *** p < 0.001
(Intercept)	6.001***	5.931***	5.934***	5.998***	6.011***
	(0.311)	(0.310)	(0.310)	(0.311)	(0.311)
TotalCrime	−0.003**			−0.004+	0.009*
	(0.001)			(0.002)	(0.004)
int_rates	−0.007***	−0.007***	−0.007***	−0.007***	−0.007***
	(0.002)	(0.002)	(0.002)	(0.002)	(0.002)
dist_to_bua_m	−0.000	−0.000	−0.001	−0.000	−0.000
	(0.001)	(0.001)	(0.001)	(0.001)	(0.001)
dist_to_trainstaion	0.008***	0.006***	0.005***	0.008***	0.008***
	(0.001)	(0.001)	(0.001)	(0.001)	(0.001)
dist_to_airport	0.011***	0.010***	0.010***	0.011***	0.011***
	(0.001)	(0.001)	(0.001)	(0.001)	(0.001)
dist_to_hos_m	−0.003**	−0.007***	−0.008***	−0.003**	−0.003**
	(0.001)	(0.001)	(0.001)	(0.001)	(0.001)
dist_to_com_air_m	−0.028***	−0.029***	−0.029***	−0.028***	−0.028***
	(0.001)	(0.001)	(0.001)	(0.001)	(0.001)
Pop_est	0.377*	0.385*	0.303+	0.378*	0.383*
	(0.173)	(0.173)	(0.173)	(0.173)	(0.173)
House_stk	−2.015***	−1.997***	−1.864***	−2.017***	−2.028***
	(0.340)	(0.340)	(0.340)	(0.340)	(0.340)
dist_to_Garda_Station_m	0.006***	0.007***	0.007***	0.006***	0.006***
	(0.001)	(0.001)	(0.001)	(0.001)	(0.001)
latitude	−0.039***	−0.037***	−0.036***	−0.039***	−0.039***
	(0.005)	(0.005)	(0.005)	(0.005)	(0.005)
longitude	0.009**	0.008**	0.008*	0.009**	0.009**
	(0.003)	(0.003)	(0.003)	(0.003)	(0.003)
County_Cavan	0.015	0.016	0.009	0.015	0.016
	(0.016)	(0.016)	(0.016)	(0.016)	(0.016)
County_Clare	0.235***	0.228***	0.211***	0.235***	0.238***
	(0.046)	(0.046)	(0.046)	(0.046)	(0.046)
County_Cork	1.888***	1.856***	1.792***	1.890***	1.895***
	(0.225)	(0.225)	(0.225)	(0.225)	(0.225)
County_Donegal	0.552***	0.544***	0.518***	0.552***	0.554***
	(0.076)	(0.076)	(0.076)	(0.076)	(0.076)
County_Dublin	5.504***	5.170***	5.134***	5.502***	5.425***
	(0.242)	(0.242)	(0.244)	(0.242)	(0.245)
County_Galway	0.836***	0.822***	0.791***	0.837***	0.841***
	(0.105)	(0.105)	(0.105)	(0.105)	(0.105)
County_Kerry	0.471***	0.465***	0.444***	0.471***	0.474***
	(0.071)	(0.071)	(0.071)	(0.071)	(0.071)
County_Kildare	0.678***	0.659***	0.646***	0.678***	0.677***
	(0.038)	(0.038)	(0.038)	(0.038)	(0.038)
County_Kilkenny	0.151***	0.148***	0.141***	0.151***	0.153***
	(0.024)	(0.024)	(0.024)	(0.024)	(0.024)
County_Laois	0.062***	0.065***	0.056**	0.062***	0.063***
	(0.018)	(0.018)	(0.018)	(0.018)	(0.018)
County_Leitrim	−0.185***	−0.184***	−0.188***	−0.185***	−0.183***
	(0.013)	(0.013)	(0.013)	(0.013)	(0.013)
County_Limerick	0.487***	0.471***	0.454***	0.488***	0.488***
	(0.059)	(0.059)	(0.059)	(0.059)	(0.059)
County_Longford	−0.149***	−0.149***	−0.152***	−0.149***	−0.148***
	(0.010)	(0.010)	(0.010)	(0.010)	(0.010)
County_Louth	0.403***	0.382***	0.376***	0.403***	0.397***
	(0.020)	(0.020)	(0.020)	(0.020)	(0.020)
County_Mayo	0.335***	0.326***	0.303***	0.335***	0.338***
	(0.062)	(0.062)	(0.062)	(0.062)	(0.062)
County_Meath	0.569***	0.555***	0.542***	0.569***	0.571***
	(0.043)	(0.043)	(0.043)	(0.043)	(0.043)
County_Offaly	−0.008	−0.008	−0.017	−0.008	−0.007
	(0.017)	(0.017)	(0.017)	(0.017)	(0.017)
County_Roscommon	−0.140***	−0.144***	−0.154***	−0.140***	−0.138***
	(0.023)	(0.022)	(0.023)	(0.023)	(0.023)
County_Sligo	0.021	0.014	0.005	0.021	0.023
	(0.020)	(0.020)	(0.020)	(0.020)	(0.020)
County_Tipperary	0.311***	0.303***	0.285***	0.311***	0.314***
	(0.059)	(0.059)	(0.059)	(0.059)	(0.059)
County_Waterford	0.158***	0.163***	0.152***	0.158***	0.159***
	(0.031)	(0.031)	(0.031)	(0.031)	(0.031)
County_Westmeath	0.182***	0.176***	0.173***	0.182***	0.184***
	(0.019)	(0.019)	(0.019)	(0.019)	(0.019)
County_Wexford	0.476***	0.464***	0.449***	0.476***	0.476***
	(0.047)	(0.047)	(0.047)	(0.047)	(0.047)
County_Wicklow	0.483***	0.476***	0.465***	0.483***	0.485***
	(0.033)	(0.033)	(0.033)	(0.033)	(0.033)
Year_X2012	−0.110***	−0.110***	−0.111***	−0.110***	−0.110***
	(0.006)	(0.006)	(0.006)	(0.006)	(0.006)
Year_X2013	−0.136***	−0.136***	−0.137***	−0.136***	−0.136***
	(0.006)	(0.006)	(0.006)	(0.006)	(0.006)
Year_X2014	−0.117***	−0.118***	−0.120***	−0.117***	−0.117***
	(0.006)	(0.006)	(0.006)	(0.006)	(0.006)
Year_X2015	−0.093***	−0.093***	−0.095***	−0.093***	−0.093***
	(0.007)	(0.007)	(0.007)	(0.007)	(0.007)
Year_X2016	−0.049***	−0.048***	−0.050***	−0.049***	−0.049***
	(0.008)	(0.008)	(0.008)	(0.008)	(0.008)
Year_X2017	−0.011	−0.008	−0.010	−0.011	−0.010
	(0.008)	(0.008)	(0.008)	(0.008)	(0.008)
Year_X2018	0.036***	0.039***	0.037***	0.036***	0.035***
	(0.010)	(0.010)	(0.010)	(0.010)	(0.010)
Year_X2019	0.058***	0.064***	0.061***	0.058***	0.058***
	(0.011)	(0.011)	(0.011)	(0.011)	(0.011)
Year_X2020	0.042*	0.050**	0.046*	0.042*	0.042*
	(0.018)	(0.018)	(0.018)	(0.018)	(0.018)
Year_X2021	0.086***	0.094***	0.090***	0.086***	0.089***
	(0.019)	(0.019)	(0.019)	(0.019)	(0.019)
Year_X2022	0.149***	0.158***	0.155***	0.149***	0.150***
	(0.019)	(0.019)	(0.019)	(0.019)	(0.019)
property_type_Second.Hand	−0.066***	−0.065***	−0.065***	−0.066***	−0.066***
	(0.002)	(0.002)	(0.002)	(0.002)	(0.002)
unit_type_House	0.118***	0.121***	0.118***	0.119***	0.118***
	(0.003)	(0.003)	(0.003)	(0.003)	(0.003)
HighIncome_Regular	−0.397***	−0.395***	−0.396***	−0.397***	−0.397***
	(0.002)	(0.002)	(0.002)	(0.002)	(0.002)
Pop_density	1.551***	1.472***	1.533***	1.550***	1.522***
	(0.205)	(0.205)	(0.205)	(0.205)	(0.206)
housing_density	−1.835***	−1.653***	−1.756***	−1.831***	−1.767***
	(0.410)	(0.409)	(0.409)	(0.410)	(0.411)
median_income	0.035**	0.033**	0.034**	0.035**	0.034**
	(0.011)	(0.011)	(0.011)	(0.011)	(0.011)
ViolentCrime		−0.034***			
		(0.002)			
NonViolentCrime		0.025***			
		(0.002)			
PersonalSafetyCrime			−0.023***		
			(0.002)		
PropertyCrime			0.014***		
			(0.002)		
TotalCrime × HighIncome_Regular				0.001	
				(0.002)	
TotalCrime_lag1					−0.012*
					(0.006)
TotalCrime_lag2					−0.000
					(0.004)
Num.Obs.	94784	94784	94784	94784	94784
R2	0.591	0.592	0.591	0.591	0.591
R2 Adj.	0.590	0.591	0.591	0.590	0.590
AIC	−21111.0	−21374.0	−21247.9	−21109.3	−21115.6
BIC	−20590.7	−20844.3	−20718.2	−20579.5	−20576.4
Log.Lik.	10610.479	10742.990	10679.963	10610.625	10614.785
F	2578.280	2542.505	2536.794	2530.521	2484.854
RMSE	0.22	0.22	0.22	0.22	0.22

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
