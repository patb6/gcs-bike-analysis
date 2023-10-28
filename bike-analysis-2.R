

rm(list = ls()) ; edatest = TRUE

library(pollster)
library(tidyverse)
library(crosstable) 
library(geosphere) 
library(rmarkdown)
library(reshape2)
library(ggpubr)
library(datadictionary)
library(knitr)

envloaded <- search() # Capture R environment
fllist <-list.files("./capstone-home/source-data", full.names = TRUE)
flrcrd <- c(769204, 823488, 785932, 701339)
flstats <- data.frame(fllist, flrcrd)



#----- Loading and maniulating data ---------
df <- list.files(path = "./capstone-home/source-data", full.names = TRUE, pattern = "*.csv") %>% map_df(~read_csv(., show_col_types = FALSE))
if(edatest) print(paste0("Total records read: ",nrow(df)))

# Create new dataframe.  
#     Keep rows where started_at < ended_at (Positive trip time)
#     Keep rows with trip information starts and end on the same day
cfile = subset(df, started_at < ended_at); if(edatest) print(paste0("Keep positive trip times ",nrow(cfile)))
cfile = subset(cfile, date(started_at) == date(ended_at)) ; if(edatest) print(paste0("Keep trips start-end on same day: ",nrow(cfile)))

# Calculate trip time
cfile$trip_time = as.numeric(difftime(cfile$ended_at, cfile$started_at, tz = "UTC", units = c("hours")))

# Keep rows not NA and triptime > 1 minute
cfile = subset(cfile, !is.na(trip_time) & trip_time*60 > 1.0)
print(paste("Trips > 1 minute: ",subset(cfile, !is.na(trip_time)) %>% nrow()))

# Keep rows where end station name and longitude exist
cfile =  subset(cfile, !(is.na(end_lng) & is.na(end_station_name)))
if(edatest) print(paste("Keep only rows where the end station and end long/lat are populated", nrow(cfile)))

# Create day of week (dow) with Monday as the starting day.
cfile$started_dow = wday(cfile$started_at, week_start = 1, label = TRUE)
cfile$ended_dow = wday(cfile$ended_at, week_start = 1, label = TRUE)


# Calculate distance based on longitude and latitude
cfile$trip_dist = distHaversine(matrix(c(cfile$start_lng,cfile$start_lat), ncol=2), matrix(c(cfile$end_lng,cfile$end_lat), ncol=2), r=3959)

# Trip time with 45 minutes or longer (factor) & bike type as factor
cfile$trip_type <- as.factor(if_else(cfile$trip_time <= 0.75, "First_45min", "Long_ride"))
cfile$member_casual <- as.factor(cfile$member_casual)
cfile$rideable_type <- as.factor(cfile$rideable_type)

if(edatest) print("Summary trip_time: ")
if(edatest) print(summary(cfile$trip_time))

if(edatest) print("Summary trip_dist: ")
if(edatest) print(summary(cfile$trip_dist))


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
if(edatest) print(paste("Samples selected: ", nrow(s)))

# --- Sample not affected by remove national holidays
s %>% select(c(trip_dist, trip_time)) %>% summary()
s %>% filter( date(started_at) != date("2022-07-04")) %>% 
  filter( date(started_at) != date("2022-09-05")) %>% 
  select(c(trip_dist, trip_time)) %>% summary()


# ----------- Set plot attributes across all plots ---------
originaltheme = theme_set(theme_get())
theme_set(theme_bw())
theme_update(plot.title = element_text(hjust = 0.5), plot.subtitle = element_text(hjust = 0.5))

# ---- From the population how many customers are casual or members
# Across the 4 months evaluated there are slightly more 'members' compared to 'casual' users
print(paste0("Population considered: ",nrow(cfile)), quote = FALSE)
kable(round(prop.table(table(cfile$member_casual))*100,2), col.names = c("Customer", "Percent"), caption = "Distribution of Customers")

# ----- Observation 1, members and casual usage changes during the week -- Correct percentages

x = prop.table(table(s$started_dow, s$member_casual),1)
x_melt <- melt(x, value.name = "pcustomer")
colnames(x_melt)[1] = "DOW"
colnames(x_melt)[2] = "Customer"
x_melt %>% ggplot(aes(x = DOW, y=pcustomer, color = Customer, group = Customer)) + geom_point() + geom_line() +
  scale_y_continuous(labels = function(x) paste0(x*100, "%")) + labs(y="% Rider Type", x ="day of week", title="Daily Customer Type (%) Usage")



# ----- Observation 2, usage of ride type differs by use  -- Correct percentages


# Ride type and customer
s %>% ggplot(aes(x= rideable_type)) + geom_bar(aes(fill = member_casual), position = position_dodge()) 

# ------ Observation 3,Casual useres will tend to use the bike longer and not travel as far.  Members will tend to the the bike further
# Looking at only Long rides (> 3/4 hour)

kable(table(s$member_casual,s$trip_type))
kable(prop.table(table(s$member_casual,s$trip_type),1))



# Scatter plot
sl45 = s %>% subset(trip_type == "First_45min") %>% select(c(trip_time, trip_dist, started_dow, member_casual)) 
kable(table(sl45$member_casual))
ggplot(sl45,aes(x = trip_time, y = trip_dist)) + geom_point(aes(color = member_casual)) +facet_wrap(~member_casual) +
  labs(title = "Customer usage when trip time <= 3/4 hour", subtitle = "Trip Time vs Distance" )

s_mean <- sl45 %>% select(c(trip_time, trip_dist, member_casual, started_dow)) %>% 
  group_by(member_casual,started_dow) %>% summarize(trip_time=mean(trip_time), trip_dist=mean(trip_dist),n()) 
ggplot(s_mean,aes(x = trip_time, y = trip_dist)) + geom_point(aes(color = started_dow)) +facet_wrap(~member_casual)
  


s_mean <- s %>% subset(trip_type == "First_45min") %>% select(c(trip_time, trip_dist, member_casual, started_dow)) %>% 
  group_by(member_casual,started_dow) %>% summarize(trip_time=mean(trip_time), trip_dist=mean(trip_dist),n()) 

 ggplot(s_mean,aes(x = trip_time, y= trip_dist)) +geom_point(aes(color = started_dow),size=4) + 
  geom_line(aes(linetype=member_casual)) +
  labs(title = "Customer usage when trip time <= 3/4 hour", subtitle = "Trip Time vs Distance" )



s %>% subset(trip_type == "Long_ride") %>% select(c(trip_time, trip_dist, started_dow)) %>% 
  ggplot(aes(x = trip_time, y = trip_dist)) + geom_point(aes(color = started_dow))


s_mean <- s %>% subset(trip_type == "Long_ride") %>% select(c(trip_time, trip_dist, member_casual, started_dow)) %>% 
  group_by(member_casual,started_dow) %>% summarize(trip_time=mean(trip_time), trip_dist=mean(trip_dist),n()) 

p2 <- s_mean %>% ggplot(aes(x = trip_time, y= trip_dist)) +geom_point(aes(color = started_dow),size=4) + 
  geom_line(aes(linetype=member_casual)) +
  labs(title = "Customer usage when trip time > 3/4 hour", subtitle = "Trip Time vs Distance" )

ggarrange(p1, p2, ncol=1, nrow = 2)








-----------------------------------

# ------ Observation
# Members ride bikes further in the middle of the week.  Casual users drive ride further the later part of the week.
x = as.data.frame( group_by(s,member_casual, started_dow) %>%   summarise(mean(trip_dist)) )
x_melt <- melt(x, value.name = "mean_trip_dist") %>% select(-c(variable))
colnames(x_melt)[1] = "Customer"
colnames(x_melt)[2] = "DOW"
x_melt %>% ggplot(aes(x = DOW, y=mean_trip_dist, color = Customer, group = Customer)) + geom_point() + geom_line()

x = as.data.frame( group_by(s,member_casual, started_dow) %>%   summarise(mean(trip_time)*60) )
x_melt <- melt(x, value.name = "mean_trip_time") %>% select(-c(variable))
colnames(x_melt)[1] = "Customer"
colnames(x_melt)[2] = "DOW"
x_melt %>% ggplot(aes(x = DOW, y=mean_trip_time, color = Customer, group = Customer)) + geom_point() + geom_line()




# samples when bike returned to starting point
se <- subset(s, start_station_id == end_station_id) ; if(edatest) nrow(se)
x = as.data.frame( group_by(se,member_casual, started_dow) %>%   summarise(mean(trip_time)) )
x_melt <- melt(x, value.name = "mean_trip_time") %>% select(-c(variable))
colnames(x_melt)[1] = "Customer"
colnames(x_melt)[2] = "DOW"
p1 <- x_melt %>% ggplot(aes(x = DOW, y=mean_trip_time, color = Customer, group = Customer)) + geom_point() + geom_line() + ylim(.2,.8)  

# sample when bike returned to different station
sne <- subset(s, start_station_id != end_station_id) ; if(edatest) nrow(sne)
x = as.data.frame( group_by(sne,member_casual, started_dow) %>%   summarise(mean(trip_time)) )
x_melt <- melt(x, value.name = "mean_trip_time") %>% select(-c(variable))
colnames(x_melt)[1] = "Customer"
colnames(x_melt)[2] = "DOW"
p2 <- x_melt %>% ggplot(aes(x = DOW, y=mean_trip_time, color = Customer, group = Customer)) + geom_point() + geom_line() + ylim(.2,.8)

ggarrange(p1+rremove("x.text"), p2, ncol=1, nrow = 2)








# ---- Explore other variables
# if(exists("smtriptime")) rm(smtriptime)


# a lot of variability not explained by casual and member cantegories
# visitors to the area
# holidays

# Separate in to same stations / different stations

se <- subset(s, start_station_id == end_station_id) ;nrow(se) # Start & End stat the same
table(se$member_casual, se$trip_type)

sne <- subset(s, start_station_id != end_station_id & started_dow == ended_dow) ;nrow(sne) # Start and end station different
table(sne$member_casual, sne$trip_type)








# ----- start and end at same station

p1 <-se %>% ggplot(aes(y = trip_time, color = member_casual)) + geom_boxplot(aes(x = member_casual)) + 
  labs(title = "start & end station same") + ylim(0,12.5)
p2 <- se %>% select(c(trip_time, trip_dist, member_casual, started_dow)) %>% 
  ggplot(aes( y=trip_time, color = member_casual)) + geom_boxplot(aes(x = started_dow)) + 
  labs(title = "start & end station same") + ylim(0,12.5)


# ----- start and end at different stations

p3 <- sne %>% ggplot(aes(y = trip_time, color = member_casual)) + geom_boxplot(aes(x=member_casual)) + 
  labs(title = "start & end station !(same)") + ylim(0,12.5)
p4 <- sne %>% select(c(trip_time, trip_dist, member_casual, started_dow)) %>% 
  ggplot(aes( y=trip_time, color = member_casual)) + geom_boxplot(aes(x = started_dow)) + 
  labs(title = "start & end station !(same)") + ylim(0,12.5)

ggarrange(p2+rremove("x.text"), p4, ncol=1, nrow = 2)



p5 <- sne %>% select(c(trip_time, trip_dist, member_casual, started_dow)) %>% 
  ggplot(aes( y=trip_dist, color = member_casual)) + geom_boxplot(aes(x = started_dow)) + ylim(0, 12.5)
p6 <- sne %>% select(c(trip_time, trip_dist, member_casual, started_dow)) %>% 
  ggplot(aes( y=trip_dist, x = trip_time, color = started_dow)) + geom_point() + facet_wrap(~member_casual) + ylim(0,12.5)
      
ggarrange(p4+rremove("x.text"), p5, p6, ncol=1, nrow = 3)

# Ride type and customer
p7 <-se %>% ggplot(aes(x= rideable_type)) + geom_bar(aes(fill = member_casual), position = position_dodge())
p8 <-sne %>% ggplot(aes(x= rideable_type)) + geom_bar(aes(fill = member_casual), position = position_dodge())
ggarrange(p7, p8, ncol=1, nrow = 2)



# ----- 10/21
# Looking at only Long rides (> 3/4 hour)
s_melt <- s %>% subset(trip_type == "Long_ride") %>% select(c(trip_time, trip_dist, member_casual, started_dow)) %>% 
  group_by(member_casual,started_dow) %>% summarize(trip_time=mean(trip_time), trip_dist=mean(trip_dist),n()) %>% melt()
s_melt %>% ggplot(aes(x = trip_time, y= trip_dist)) +geom_point(aes(color = started_dow),size=4) + 
  geom_line(aes(linetype=member_casual)) +
  labs(title = "customer usage when trip time > 3/4 hour", subtitle = "Trip Time vs Distance" )

  










