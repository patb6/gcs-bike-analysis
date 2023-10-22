

rm(list = ls())

library(pollster)
library(tidyverse)
library(crosstable) 
library(geosphere) 
library(rmarkdown)
library(reshape2)

library(knitr)

envloaded <- search() # Capture R environment
fllist <-list.files("./capstone-home/source-data", full.names = TRUE)
flrcrd <- c(769204, 823488, 785932, 701339)
flstats <- data.frame(fllist, flrcrd)


#----- Loading and maniulating data ---------
df <- list.files(path = "./capstone-home/source-data", full.names = TRUE, pattern = "*.csv") %>% map_df(~read_csv(., show_col_types = FALSE))


# Create new dataframe.  Keep rows where started_at < ended_at (Positive trip time)
cfile = subset(df, started_at < ended_at)

# Calculate trip time
cfile$trip_time = as.numeric(difftime(cfile$ended_at, cfile$started_at, tz = "UTC", units = c("hours")))
print(paste("Keep rows where started_at < ended_at: ",nrow(cfile)))

# Keep rows not NA and triptime > 1 minute
cfile = subset(cfile, !is.na(trip_time) & trip_time*60 > 1)
print(paste("Trips > 1 minute: ",subset(cfile, !is.na(trip_time)) %>% nrow()))

# Keep rows where end station name and longitude exist
cfile =  subset(cfile, !(is.na(end_lng) & is.na(end_station_name)))
print(paste("Keep only rows where the end station and end long/lat are populated", nrow(cfile)))

# Create day of week (dow) with Monday as the starting day.
cfile$started_dow = wday(cfile$started_at, week_start = 1, label = TRUE)
cfile$ended_dow = wday(cfile$ended_at, week_start = 1, label = TRUE)

# Calculate distance based on longitude and latitude
cfile$trip_dist = distHaversine(matrix(c(cfile$start_lng,cfile$start_lat), ncol=2), matrix(c(cfile$end_lng,cfile$end_lat), ncol=2), r=3959)

# Trip time with 45 minutes or longer (factor) & bike type as factor
cfile$trip_type <- as.factor(if_else(cfile$trip_time <= 0.75, "First_45min", "Long_ride"))
cfile$rideable_type <- as.factor(cfile$rideable_type)

print(paste("Longest trip time (hours):  ",max(cfile$trip_time)))
print(paste("Shortest trip time (min): ",min(cfile$trip_time)*60))

print("Summary trip_time: ")
print(summary(cfile$trip_time))

print("Summary trip_dist: ")
print(summary(cfile$trip_dist))






rseed = 53679
set.seed(rseed)         # Set seed for reproducability
obs_rows = nrow(cfile)  # dataset size
obs_prcnt = .01         # sample percentage
obs_samp = round(obs_rows*obs_prcnt,0)

# Pick same number of members and casual users
s = subset(cfile, member_casual == "casual")
s_c = s[sample(nrow(s),obs_samp),]
s = subset(cfile, member_casual == "member")
s_m = s[sample(nrow(s),obs_samp),]
s = rbind(s_m,s_c)
print(paste("Samples selected: ", nrow(s)))



# ----------- Set plot attributes across all plots ---------
originaltheme = theme_set(theme_get())
theme_set(theme_bw())
theme_update(plot.title = element_text(hjust = 0.5))



# ----- Observation 1, members and casual usage changes during the week -- Correct percentages

x = prop.table(table(s$started_dow, s$member_casual),1)
x_melt <- melt(x, value.name = "pcustomer")
colnames(x_melt)[1] = "DOW"
colnames(x_melt)[2] = "Customer"
x_melt %>% ggplot(aes(x = DOW, y=pcustomer, color = Customer, group = Customer)) + geom_point() + geom_line() +
  scale_y_continuous(labels = function(x) paste0(x*100, "%")) + labs(y="% Rider Type", x ="day of week", title="Daily Customer Type (%) Usage")


# ---- Explore other variables
if(exists("smtriptime")) rm(smtriptime)

t <-subset(s, round(trip_time,2) <= 0.75 & started_dow == ended_dow)
print(paste0("Total samples with trip time < 0.75mi:  ",nrow(t)))
pt <- print(paste0("Trip time <= 0.75 \n n= ",nrow(t)))
ylinemedian <-data.frame(yintercept = median(t$trip_time), Lines=paste0("Median ",round(median(t$trip_time),2)))
ylinemean   <-data.frame(yintercept = mean(t$trip_time), Lines=paste0("Mean ",round(mean(t$trip_time),2)))
ggplot(t, aes(x = started_dow, y = trip_time, color = member_casual)) +geom_boxplot() +
  labs(title=pt) + 
  geom_hline(aes(yintercept = yintercept, linetype = Lines), ylinemedian) + 
  geom_hline(aes(yintercept = yintercept, linetype = Lines), ylinemean)

ggplot(t, aes(x = rideable_type, y = trip_time, color = member_casual))  +geom_boxplot() +
  labs(title=pt) +
  geom_hline(aes(yintercept = yintercept, linetype = Lines), ylinemedian) + 
  geom_hline(aes(yintercept = yintercept, linetype = Lines), ylinemean)


smtriptime = data.frame(summarise(t, median(trip_time), mean(trip_time), max(trip_time), n()))


t <-subset(s,(round(trip_time,2) > 0.75 & round(trip_time,2) <= 3.0) & started_dow == ended_dow)
pt <- print(paste0("Trip time >0.75 and <= 3.0 hours \n n= ",nrow(t)))
print(paste0("Total samples with trip time > 0.75mi and trip_time < 3.0:  ",nrow(t)))
ylinemedian <-data.frame(yintercept = median(t$trip_time), Lines=paste0("Median ",round(median(t$trip_time),2)))
ylinemean   <-data.frame(yintercept = mean(t$trip_time), Lines=paste0("Mean ",round(mean(t$trip_time),2)))

ggplot(t, aes(x = started_dow, y = trip_time, color = rideable_type)) +geom_boxplot() + facet_wrap(~member_casual, scales = "free") +
  labs(title=pt) + 
  geom_hline(aes(yintercept = yintercept, linetype = Lines), ylinemedian) + 
  geom_hline(aes(yintercept = yintercept, linetype = Lines), ylinemean)

ggplot(t, aes(x = rideable_type, y = trip_time, color = member_casual))  +geom_boxplot() +
  labs(title=pt) +
  geom_hline(aes(yintercept = yintercept, linetype = Lines), ylinemedian) + 
  geom_hline(aes(yintercept = yintercept, linetype = Lines), ylinemean)

smtriptime = rbind(smtriptime,data.frame(summarise(t, median(trip_time), mean(trip_time), max(trip_time), n())))




t <-subset(s,round(trip_time,2) > 3.0  & started_dow == ended_dow)
pt <- print(paste0("Trip time > 3.0 hours \n n= ",nrow(t)))
print(paste0("Total samples with trip time > 3.0:  ",nrow(t)))
ylinemedian <-data.frame(yintercept = median(t$trip_time), Lines=paste0("Median ",round(median(t$trip_time),2)))
ylinemean   <-data.frame(yintercept = mean(t$trip_time), Lines=paste0("Mean ",round(mean(t$trip_time),2)))

ggplot(t, aes(x = started_dow, y = trip_time, color = member_casual)) +geom_boxplot() +
  labs(title=pt) + 
  geom_hline(aes(yintercept = yintercept, linetype = Lines), ylinemedian) + 
  geom_hline(aes(yintercept = yintercept, linetype = Lines), ylinemean)
smtriptime = rbind(smtriptime,data.frame(summarise(t, median(trip_time), mean(trip_time), max(trip_time), n())))

ggplot(t, aes(x = rideable_type, y = trip_time, color = member_casual))  + geom_boxplot() +
  labs(title=pt) +
  geom_hline(aes(yintercept = yintercept, linetype = Lines), ylinemedian) + 
  geom_hline(aes(yintercept = yintercept, linetype = Lines), ylinemean)


smtriptime = cbind(c("<=0.75",">.75 & <=3",">3"),smtriptime)
colnames(smtriptime) = c("Trip Time", "Median", "Mean","Max","n")

kable(smtriptime)

# -------- archive

t <-subset(s,round(trip_time,2) > 0.75 & started_dow == ended_dow)
pt <- print(paste0("Trip time < 0.75 \n n= ",nrow(t)))
print(paste0("Total samples with trip time > 0.75mi:  ",nrow(t)))
ylinemedian <-data.frame(yintercept = median(t$trip_time), Lines=paste0("Median ",round(median(t$trip_time),2)))
ylinemean   <-data.frame(yintercept = mean(t$trip_time), Lines=paste0("Mean ",round(mean(t$trip_time),2)))

ggplot(t, aes(x = started_dow, y = trip_time, color = member_casual)) +geom_boxplot() +
  labs(title=pt) + 
  geom_hline(aes(yintercept = yintercept, linetype = Lines), ylinemedian) + 
  geom_hline(aes(yintercept = yintercept, linetype = Lines), ylinemean)
summarise(t, median(trip_time), mean(trip_time), max(trip_time))




