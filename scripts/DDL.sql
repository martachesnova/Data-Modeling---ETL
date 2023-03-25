CREATE SCHEMA IF NOT EXISTS INSIGHTS;

CREATE OR REPLACE TABLE INSIGHTS.STORE (
    store_id int,
    manager_firstname varchar(50),
    manager_lastname varchar(50),
    address varchar(500),
    address2 varchar(500),
    district varchar(50),
    city_name varchar(50),
    postal_code varchar(10),
    phone varchar(20),
    country_name varchar(50)
);

CREATE OR REPLACE TABLE INSIGHTS.CUSTOMERS (
    customer_id int,
    first_name varchar(50),
    last_name varchar(50),
    email varchar(500),
    create_date timestamp,
    address varchar(500),
    address2 varchar(500),
    district varchar(20),
    city_name varchar(50),
    postal_code varchar(10),
    phone varchar(20),
    coutry_name varchar(50),
    active boolean
);

CREATE OR REPLACE TABLE INSIGHTS.EMPLOYEES (
    employee_id int,
    manager_firstname varchar(50),
    manager_lastname varchar(50),
    address varchar(500),
    address2 varchar(500),
    picture varchar (200),
    email varchar(500),
    username  varchar(500),
    password  varchar(500),
    district varchar(20),
    city_name varchar(50),
    postal_code varchar(10),
    phone varchar(20),
    country_name varchar(50),
    active boolean
);

CREATE OR REPLACE TABLE INSIGHTS.FILM (
    film_id int,
    title varchar(500),
    description text,
    released_year int,
    language varchar(20),
    original_language varchar(20),
    rental_duration int,
    rental_rate numeric,
    length int,
    replace_cost numeric,
    rating varchar(100),
    special_features varchar(100),
    actor_first_name varchar(50),
    actor_last_name varchar(50),
    category_name varchar(50)
);

CREATE OR REPLACE TABLE INSIGHTS.CALENDAR (
    calendar_dt date,
    day_of_wk_num int,
    day_of_wk_desc varchar(30),
    yr_num int,
    wk_num int,
    yr_wk_num int,
    mnth_num int,
    yr_mnth_num int 
);

CREATE OR REPLACE TABLE INSIGHTS.TRANSACTIONS (
    transact_date date,
    customer_id int,
    employee_id int,
    store_id int,
    film_id int,
    amount numeric,
    declined boolean
);