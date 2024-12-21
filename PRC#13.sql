#################1######################

SELECT dc.city_name,
COUNT(trip_id) as total_trips,
ROUND((select AVG(fare_amount/distance_travelled_km ) 
from trips_db.fact_trips
join dim_city dc2
USING (city_id)
where dc2.city_name=dc.city_name
),2) AS AVG_fare_per_km, ## Getting Average fare per KM using subquery
ROUND((select SUM(fare_amount)/count(trip_id)
from trips_db.fact_trips
join dim_city dc2
USING (city_id)
where dc2.city_name=dc.city_name
),2) AS AVG_fare_per_trip,  ## Getting Average fare per Trip using subquery
round(count(trip_id)/(SELECT count(trip_id) from fact_trips)*100,2) as percnt_contribution_to_total_trip #getting percetage every city sum of trips with overall sum of trips
FROM dim_city dc
JOIN fact_trips
USING (city_id)
GROUP BY city_name
order by  percnt_contribution_to_total_trip desc;



####################2222222222222#####################
## getting monthname,city name andcount of actual trips fromcte
WITH cte as (
SELECT MONTHname(date) as month_name ,
dc.city_id,
dc.city_name as City_name,
count(trip_id) as actual_trip
from trips_db.fact_trips ft
join dim_city dc
USING (city_id)
GROUP BY month_name,City_name,dc.city_id
),
##now we get targets trip from total target trips table using cte2
CTE2 as (
SELECT c.month_name,c.City_name,c.actual_trip,total_target_trips FROM cte c
JOIN targets_db.monthly_target_trips mt
on monthname(mt.month)=c.month_name
AND mt.city_id=c.city_id)

#now we creating our actual outut with Performance status
select *,
case
WHEN actual_trip>total_target_trips THEN "Above Target"
WHEN actual_trip<total_target_trips THEN "Below Target"
end as Performance_status,
ROUND((actual_trip-total_target_trips)*100/total_target_trips,2)as Percent_difference
 from cte2
;

###########3333333333###########################

SELECT dc.city_name,
#from below code we are using case statement, filtering our desire repeat trip frequency
round(SUM(case when trip_count='2-Trips' THEN repeat_passenger_count ELSE 0 END)*100/sum(repeat_passenger_count),1) AS 2_Trips,
round(SUM(case when trip_count='3-Trips' THEN repeat_passenger_count ELSE 0 END)*100/sum(repeat_passenger_count),1)  AS 3_Trips,
round(SUM(case when trip_count='4-Trips' THEN repeat_passenger_count ELSE 0 END)*100/sum(repeat_passenger_count),1)  AS 4_Trips,
round(SUM(case when trip_count='5-Trips' THEN repeat_passenger_count ELSE 0 END)*100/sum(repeat_passenger_count),1)  AS 5_Trips,
round(SUM(case when trip_count='6-Trips' THEN repeat_passenger_count ELSE 0 END)*100/sum(repeat_passenger_count),1)  AS 6_Trips,
round(SUM(case when trip_count='7-Trips' THEN repeat_passenger_count ELSE 0 END)*100/sum(repeat_passenger_count),1)  AS 7_Trips,
round(SUM(case when trip_count='8-Trips' THEN repeat_passenger_count ELSE 0 END)*100/sum(repeat_passenger_count),1)  AS 8_Trips,
round(SUM(case when trip_count='9-Trips' THEN repeat_passenger_count ELSE 0 END)*100/sum(repeat_passenger_count),1)  AS 9_Trips,
round(SUM(case when trip_count='10-Trips' THEN repeat_passenger_count ELSE 0 END)*100/sum(repeat_passenger_count),1)  AS 10_Trips
FROM trips_db.dim_repeat_trip_distribution
JOIN dim_city dc
USING(city_id)
group by city_name
;

######################4444444444444444444444444###########################

(
SELECT dc.city_name,sum(new_passengers) as New_passengers, "TOP 3" as city_category
FROM trips_db.fact_passenger_summary
JOIN dim_city dc
USING(city_id)
Group by dc.city_name
ORDER BY New_passengers DESC
limit 3)
UNION
(SELECT dc.city_name,sum(new_passengers) as New_passengers, "Bottom 3" as city_category
FROM trips_db.fact_passenger_summary
JOIN dim_city dc
USING(city_id)
Group by dc.city_name
ORDER BY New_passengers
limit 3
);
##############################5555555555555555555555####################
## first we use CtE to get each city month with total revenue, we use window funtion inside..
## ..cte to partion the rank by city
with cte as (
SELECT dc.city_name as city, monthname(date) as heighest_revenue_month,
sum(fare_amount) as Revenue,
ROW_NUMBER() OVER (partition by dc.city_name ORDER BY sum(fare_amount) DESC) AS rank_desc
FROM trips_db.fact_trips
JOIN dim_city dc
USING(city_id)
group by city,heighest_revenue_month )
## in ur main query below, we add filter to display only result whoese rank is less then 2
## alsi get % by deviding city trip with overll month Trip sum
SELECT c.city, heighest_revenue_month, round(Revenue*100/(select sum(fare_amount)
from trips_db.fact_trips ft
JOIN dim_city dc
USING(city_id)
WHERE c.city=dc.city_name
),2) as percentage_contribution
from cte c
where rank_desc <2
;

#####################6666666666666666666666###################
#below CTE will getcite name along id, months and monthle repear rate
with CM as (
SELECT dc.city_name as city_name ,dc.city_id as id, MONTHname(month) as month,
ROUND(sum(repeat_passengers)*100/sum(total_passengers),2) as monthly_repeat_pessenger_rate
FROM trips_db.fact_passenger_summary
JOIN dim_city dc
USING(city_id)
GROUP BY MONTHname(month),city_id,city_name
),

#below cte give overall city repeat %, along with city_id and name_
c as(
SELECT dc.city_name as city_name , dc.city_id as id,
ROUND(sum(repeat_passengers)*100/sum(total_passengers),2) as city_repeat_pessenger_rate
FROM trips_db.fact_passenger_summary
JOIN dim_city dc
USING(city_id)
GROUP BY city_id, dc.city_id

),
#below cte will give us city_name,city_id, month,total_passenger,repeat_passenger
sum as (
SELECT dc.city_name as city_name ,dc.city_id as id, MONTHname(month) as month,
sum(total_passengers) as total_passenger,
sum(repeat_passengers) as repeat_passenger
 FROM trips_db.fact_passenger_summary fps
 JOIN dim_city dc
 using(city_id)
 group by city_name,id,month
 )
 #now we combine result of 3 quries in our fial output query
 SELECT sum.city_name,sum.month,sum.total_passenger,sum.repeat_passenger,
 cm.monthly_repeat_pessenger_rate,
 c.city_repeat_pessenger_rate
 FROM sum
 join c on sum.id=c.id 
 join cm on sum.id=cm.id AND sum.month=cm.month
 order by sum.city_name