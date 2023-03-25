USE DATABASE MY_STORE_LAB;

TRUNCATE TABLE IF EXISTS INSIGHTS.STORE;
INSERT INTO INSIGHTS.STORE (
    store_id,
    manager_firstname,
    manager_lastname,
    address,
    address2,
    district,
    city_name,
    postal_code,
    phone,
    country_name
)
SELECT 
    s.store_id,
    st.first_name,
	st.last_name,
	a.address,
	a.address2,
	a.district,
	ct.city AS city_name,
	a.postal_code,
	a.phone,
	cn.country AS country_name
FROM WCD_LAB.SAKILA.store s
LEFT JOIN WCD_LAB.SAKILA.staff st ON s.manager_staff_id=st.staff_id
LEFT JOIN WCD_LAB.SAKILA.address a ON s.address_id=a.address_id
LEFT JOIN WCD_LAB.SAKILA.city ct USING (city_id)
LEFT JOIN WCD_LAB.SAKILA.country cn USING (country_id);

TRUNCATE TABLE IF EXISTS INSIGHTS.CUSTOMERS;
INSERT INTO INSIGHTS.CUSTOMERS (
    customer_id,
    first_name,
    last_name,
    email,
    create_date,
    address,
    address2,
    district,
    city_name,
    postal_code,
    phone,
    coutry_name,
    active
)
SELECT 
	c.customer_id,
	c.first_name,
	c.last_name,
	c.email,
	c.create_date,
	a.address,
	a.address2,
	a.district,
	ct.city AS city_name,
	a.postal_code,
	a.phone,
	cn.country AS country_name,
	c.active
FROM WCD_LAB.SAKILA.customer c
LEFT JOIN WCD_LAB.SAKILA.address a USING (address_id)
LEFT JOIN WCD_LAB.SAKILA.city ct USING (city_id)
LEFT JOIN WCD_LAB.SAKILA.country cn USING (country_id);

TRUNCATE TABLE IF EXISTS INSIGHTS.EMPLOYEES;
INSERT INTO INSIGHTS.EMPLOYEES (
    employee_id,
    manager_firstname,
    manager_lastname,
    address,
    address2,
    picture,
    email,
    username,
    password,
    district,
    city_name,
    postal_code,
    phone,
    country_name,
    active
)
SELECT 
	s.staff_id,
	s.first_name,
	s.last_name,
	a.address,
	a.address2,
	s.picture,
	s.email,
	s.username,
	s.password,
	a.district,
	ct.city AS city_name,
	a.postal_code,
	a.phone,
	cn.country AS country_name,
	s.active
FROM WCD_LAB.SAKILA.staff s
LEFT JOIN WCD_LAB.SAKILA.address a USING (address_id)
LEFT JOIN WCD_LAB.SAKILA.city ct USING (city_id)
LEFT JOIN WCD_LAB.SAKILA.country cn USING (country_id);

TRUNCATE TABLE IF EXISTS INSIGHTS.FILM;
INSERT INTO INSIGHTS.FILM (
    film_id,
    title,
    description,
    released_year,
    language,
    original_language,
    rental_duration,
    rental_rate,
    length,
    replace_cost,
    rating,
    special_features,
    actor_first_name,
    actor_last_name,
    category_name
)
SELECT 
	f.film_id,
	f.title,
	f.description,
	f.release_year AS released_year,
	l.name as language,
	ll.name as original_language,
	f.rental_duration,
	f.rental_rate,
	f.length,
	f.replacement_cost AS replace_cost,
	f.rating,
	f.special_features,
	a.first_name AS actor_first_name,
    a.last_name AS actor_last_name,
    c.name as category_name
FROM WCD_LAB.SAKILA.film f
LEFT JOIN WCD_LAB.SAKILA.LANGUAGE l USING (language_id)
LEFT JOIN WCD_LAB.SAKILA.LANGUAGE ll USING (language_id)
LEFT JOIN WCD_LAB.SAKILA.film_actor fa USING (film_id)
LEFT JOIN WCD_LAB.SAKILA.actor a ON fa.actor_id=a.actor_id
LEFT JOIN WCD_LAB.SAKILA.film_category fc USING (film_id)
LEFT JOIN WCD_LAB.SAKILA.category c ON fc.category_id=c.category_id;


-- TRUNCATE TABLE IF EXISTS INSIGHTS.CALENDAR;
-- INSERT INTO INSIGHTS.CALENDAR (
--     --transact_date date,
--     calendar_dt date,
--     day_of_wk_num,
--     day_of_wk_desc,
--     yr_num,
--     wk_num,
--     yr_wk_num,
--     mnth_num,
--     yr_mnth_num
-- );

-- POPULATE FACT TABLE
-- we first join the payment, inventory and rental tables to create a base transient table
CREATE OR REPLACE TRANSIENT TABLE INSIGHTS.TRANS_BASE_STG AS  
SELECT
	p.payment_date AS transact_date,
	p.customer_id,
	p.staff_id,
	i.store_id,
	i.film_id,
	p.amount
FROM WCD_LAB.SAKILA.PAYMENT p 
JOIN WCD_LAB.SAKILA.RENTAL r USING (rental_id, customer_id, staff_id)
JOIN WCD_LAB.SAKILA.INVENTORY i ON r.inventory_id = i.inventory_id;

-- generate the is_decline column
----- The steps are:
------ find the latest date of the transaction
SET max_dt = (SELECT max(payment_date) FROM WCD_LAB.SAKILA.PAYMENT);

------ get he last 4 weeks, the week number and date range to create a transient table
CREATE OR REPLACE TRANSIENT TABLE INSIGHTS.LAST_4_WK_STG AS 
SELECT 
	c.calendar_dt,
	c.yr_wk_num
FROM INSIGHTS.CALENDAR c
JOIN 
		(SELECT 
			yr_wk_num
		FROM INSIGHTS.CALENDAR
		WHERE calendar_dt <=$max_dt
		GROUP BY yr_wk_num
		ORDER BY yr_wk_num desc
		LIMIT 4) USING (yr_wk_num);

------ build a week + store framework. The reason why we cross join week and store, is because we want to create a framework to make sure the all weeks and stores
------ are listed no matter there are any transaction or not in that date in the payment table.
CREATE OR REPLACE TRANSIENT TABLE INSIGHTS.LAST_4_WK_STORE_STG AS 
SELECT 
	w.yr_wk_num,
	s.store_id,
	w.calendar_dt
FROM INSIGHTS.LAST_4_WK_STG w
CROSS JOIN INSIGHTS.STORE s;

------ filter out the sum transaction with the latest 4 weeks
CREATE OR REPLACE TRANSIENT TABLE INSIGHTS.LAST_4_WK_TRANS_STG AS 
SELECT 
	w.store_id,
	w.yr_wk_num,
	nvl(sum(t.amount),0) AS wk_amount
FROM 
INSIGHTS.LAST_4_WK_STORE_STG w 
LEFT JOIN INSIGHTS.TRANS_BASE_STG t  ON t.transact_date=w.calendar_dt
GROUP BY 1,2
ORDER BY 1,2;

------ find out if the late week amount less than that in previous week
------in the sub-query there are several steps:
-------- 1)  based on the "last_4_wk_trans_stg" table create a new column 'the last wk_amount' 
-------- 2)   make the wk amount minus last wk amount, if negative then we label it as -1, this will be a new table called 'wk_decline'
-------- 3)  sum total 'wk_decline' of a store, if it is -3, it means last 3 weeks all less than the later week, this means totally 4 weeks decline, so we can label
----------- the is_decline column true.

CREATE OR REPLACE TRANSIENT TABLE INSIGHTS.LAST_4_WK_DECLINE AS 
SELECT 
    store_id,
    CASE WHEN sum_decline=-3 THEN TRUE ELSE FALSE END AS decline 
FROM 
    (select  store_id, sum(wk_decline) as sum_decline
    from  
        (SELECT *, CASE WHEN wk_amount - last_wk_amount<=0 THEN -1 ELSE 0 END AS wk_decline
        FROM  
            (select  *, lead(wk_amount) over (partition by store_id order by yr_wk_num) as last_wk_amount 
            from INSIGHTS.LAST_4_WK_TRANS_STG)
        WHERE last_wk_amount IS NOT NULL)
    group by 1);

------ finally we join this column with the TRANS_BASE_STG table, to create the final transaction transient table.
CREATE OR REPLACE TRANSIENT TABLE INSIGHTS.TRANSACTIONS_STG AS 
SELECT 
    t.*,
	w.decline
FROM INSIGHTS.TRANS_BASE_STG t
JOIN INSIGHTS.LAST_4_WK_DECLINE w USING (store_id);


------ replace the current transaction table with new transaction transient table
TRUNCATE TABLE IF EXISTS INSIGHTS.TRANSACTIONS;
INSERT INTO INSIGHTS.TRANSACTIONS (
    transact_date,
    customer_id,
    employee_id,
    store_id,
    film_id,
    amount,
    declined
)
SELECT 
    transact_date,
    customer_id,
    staff_id,
    store_id,
    film_id,
    amount,
    decline
FROM INSIGHTS.TRANSACTIONS_STG;
