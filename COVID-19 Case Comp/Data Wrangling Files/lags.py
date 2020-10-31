import pandas as pd
import numpy as np

# Samuel's data set
ont_data = pd.read_csv("data_can2.csv")

# create new variables
ont_data = ont_data.assign(
    new_confirmed = ont_data["confirmed"].diff(),
    new_tests = ont_data["tests"].diff(),
    new_recovered = ont_data["recovered"].diff()
    )

# Ontario data
ont_data = ont_data[ont_data["key_apple_mobility"] == "Ontario"]
ont_data["date"] = pd.to_datetime(ont_data["date"])

# Ontario data on estimated positive case onset dates
pos_data = pd.read_csv("conposcovidloc.csv")
pos_data["Accurate_Episode_Date"] = pd.to_datetime(pos_data["Accurate_Episode_Date"])
pos_data["Test_Reported_Date"] = pd.to_datetime(pos_data["Test_Reported_Date"])

# Create lag variable
lag = pos_data["Test_Reported_Date"] - pos_data["Accurate_Episode_Date"]
pos_data['lag'] = lag.dt.days # timedelta object to integer for means
mean_lag = pos_data.groupby(by='Accurate_Episode_Date').mean()['lag']
mean_lag_dates = pd.Series(mean_lag.index.values)
mean_lag = pd.Series(mean_lag.values)
mean_lag_data = pd.concat([mean_lag_dates, mean_lag], axis = 1)
mean_lag_data.columns = ["date", "mean_lag"]

# estimated date of onset for confirmed positive cases
onset_date = pos_data["Accurate_Episode_Date"]
cases = pd.Series(onset_date.value_counts().values)
date = pd.Series(onset_date.value_counts().index.values)
date = pd.to_datetime(date)
onset_data = pd.concat([date, cases], axis=1)
onset_data.columns = ['date', 'onset']

# merge the data frames
onset_data = onset_data.merge(mean_lag_data, on = "date")
onset_data["date"] = pd.to_datetime(onset_data["date"])

# The data frame below has the following new variables:
# onset: Number of confirmed positives whose symptoms started on that date.
# mean_lag: The mean number of days it took to report the confirmed cases whose
# onset of symptoms was the corresponding date.
ont_data = ont_data.merge(onset_data, on = "date")
