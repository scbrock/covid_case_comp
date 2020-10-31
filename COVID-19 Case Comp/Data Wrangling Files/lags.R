library(ggplot2)
library(dplyr)
library(data.table)

df = read.csv("data_can2.csv")
df <- data.table(df)

responses <- names(df)[5:8] # similar to Samuel's code

# create new variables for "number of new.."
df[, (paste0("new_", responses)) := lapply(.SD, function(v) c(0,diff(v))),
   .SDcols = responses]
df = df[, -c(9:11)] # Remove NA columns
df$date = as.Date(df$date) # change type from factor to date

# filter to just Ontario data for daily 
ont_data = filter(df, key_apple_mobility == "Ontario") 

# read in data frame for confirmed positive cases and estimated date of onset
pos_data = read.csv("conposcovidloc.csv", stringsAsFactors = FALSE)
onset_date = pos_data$Accurate_Episode_Date
onset_date = data.frame(table(onset_date)) # aggregate counts by date
colnames(onset_date) = c("date", "onset") #rename columns

# need to format dates
onset_date$date = strptime(onset_date$date,format="%Y-%m-%d")
onset_date$date = as.Date(onset_date$date)

# join data along date column
ont_data = inner_join(ont_data, onset_date, by = "date")

#
#
# Visualizing lag in Ontario data
#
#

# Visualized lag between estimated onset and number of new cases
ggplot(data = ont_data, aes(x = date, y = new_confirmed)) +
    geom_point(color = "red") +
    geom_point(aes(x = date, y = onset), color = "blue")

ggplot(data = ont_data, aes(x = date, y = new_confirmed)) +
    geom_smooth(color = "red") +
    geom_smooth(aes(x = date, y = onset), color = "blue")

#
#
# Estimated Lag
#
#

# format dates again
pos_data$Accurate_Episode_Date = strptime(pos_data$Accurate_Episode_Date,format="%Y-%m-%d")
pos_data$Accurate_Episode_Date = as.Date(pos_data$Accurate_Episode_Date)
pos_data$Test_Reported_Date = strptime(pos_data$Test_Reported_Date,format="%Y-%m-%d")
pos_data$Test_Reported_Date = as.Date(pos_data$Test_Reported_Date)

# create lage column: difference between reported date and date of onset 
lag = pos_data$Test_Reported_Date - pos_data$Accurate_Episode_Date
lag = as.numeric(unlist(lag)) # list to numeric vector
onset = pos_data$Accurate_Episode_Date
lag_data = data.frame(onset, lag) # create a lag dataframe for plotting

# Histogram for lag between estimated onset and reported test
ggplot(data = lag_data, aes(x = lag)) +
    geom_histogram(binwidth = 5)

# Summary statistics.
summary(lag)

# for each onset date, take the mean number of days to report the case
mean_lag_data = aggregate(lag ~ onset, data=lag_data, FUN = mean)
colnames(mean_lag_data) = c("date", "mean_lag")
# format dates
mean_lag_data$date = strptime(mean_lag_data$date,format="%Y-%m-%d")
mean_lag_data$date = as.Date(mean_lag_data$date)

# plot mean lags by onset date
ggplot(data = mean_lag_data, aes(x = date, y = mean_lag)) +
    geom_point()

# limit the y axis to get a better look of the rightside
ggplot(data = mean_lag_data, aes(x = date, y = mean_lag)) +
    geom_point() +
    ylim(0, 20)