CREATE DATABASE IF NOT EXISTS Energy;
USE Energy;

CREATE TABLE country (
    country VARCHAR(255) PRIMARY KEY,
    cid VARCHAR(50)
);

CREATE TABLE emission_3 (
    country VARCHAR(255),
    energy_type VARCHAR(255),
    year INT,
    emission INT,
    per_capita_emission DOUBLE,
    FOREIGN KEY (country) REFERENCES country(country)
);

CREATE TABLE population (
    country VARCHAR(255),
    year INT,
    population_value DOUBLE,
    FOREIGN KEY (country) REFERENCES country(country)
);

CREATE TABLE production (
    country VARCHAR(255),
    energy VARCHAR(255),
    year INT,
    production INT,
    FOREIGN KEY (country) REFERENCES country(country)
);

CREATE TABLE gdp_3 (
    country VARCHAR(255),
    year INT,
    gdp_value DOUBLE,
    FOREIGN KEY (country) REFERENCES country(country)
);

CREATE TABLE consumption (
    country VARCHAR(255),
    energy VARCHAR(255),
    year INT,
    consumption INT,
    FOREIGN KEY (country) REFERENCES country(country)
);

SELECT * FROM country;
SELECT * FROM emission_3;
SELECT * FROM population;
SELECT * FROM production;
SELECT * FROM gdp_3;
SELECT * FROM consumption;


/* Analysis Questions
1.a How much energy is consumed and produced by each country?
1.b The relationship between energy consumption/production and CO₂ emissions.
1.c Comparison of countries in terms of their energy efficiency (e.g., emissions per unit of GDP or per unit of energy consumed).
*/

-- Energy consumed and produced
SELECT c.country, 
	   SUM(cons.consumption) AS total_consumption, 
       SUM(prod.production) AS total_production
FROM country c
LEFT JOIN consumption cons ON c.country = cons.country
LEFT JOIN production prod ON c.country = prod.country AND cons.year = prod.year
GROUP BY c.country
ORDER BY total_consumption DESC
LIMIT 10;

-- Relationship b/w consumption/production and CO₂ emissions
SELECT 
    c.country,
    SUM(cons.consumption) AS total_consumption,
    SUM(prod.production) AS total_production,
    SUM(COALESCE(e.emission, 0)) AS total_emission
FROM country c
LEFT JOIN consumption cons ON c.country = cons.country
LEFT JOIN production prod ON c.country = prod.country AND cons.year = prod.year
LEFT JOIN emission_3 e ON c.country = e.country AND cons.year = e.year
GROUP BY c.country
ORDER BY total_emission DESC
LIMIT 10;

-- Comparison
-- Emissions per unit GDP
SELECT 
    e.country,
    SUM(e.emission) / SUM(gdp.gdp_value) AS emission_per_gdp
FROM emission_3 e
JOIN gdp_3 gdp ON e.country = gdp.country AND e.year = gdp.year
GROUP BY e.country
ORDER BY emission_per_gdp DESC
LIMIT 10;

-- Emissions per unit of energy consumed
SELECT 
    e.country,
    SUM(e.emission) AS total_emission,
    SUM(c.consumption) AS total_consumption,
    ROUND(SUM(e.emission) / SUM(c.consumption), 3) AS emission_per_energy
FROM emission_3 e
JOIN consumption c 
  ON e.country = c.country AND e.year = c.year
GROUP BY e.country
HAVING total_emission IS NOT NULL AND total_consumption IS NOT NULL
ORDER BY emission_per_energy DESC;

/* Analysis Questions
2.a GDP and population data with emissions and energy 
2.b Per capita emissions 
2.c Emissions per GDP unit 
2.d Identify economically productive but low-emission countries (good models for sustainability)
*/

-- GDP and population data with emissions and energy
WITH gdp_data  AS (SELECT country, year, gdp_value FROM gdp_3),
	 pop_data  AS (SELECT country, year, population_value FROM population),
	 em_data   AS (SELECT country, year, SUM(emission) AS total_emission FROM emission_3 GROUP BY country, year),
	 cons_data AS (SELECT country, year, SUM(consumption) AS total_consumption FROM consumption GROUP BY country, year),
	 prod_data AS (SELECT country, year, SUM(production) AS total_production FROM production GROUP BY country, year)
SELECT 
    gdp.country,
    gdp.year,
    gdp.gdp_value,
    pop.population_value,
    em.total_emission,
    cons.total_consumption,
    prod.total_production
FROM gdp_data gdp
JOIN pop_data pop ON gdp.country = pop.country AND gdp.year = pop.year
JOIN em_data em ON gdp.country = em.country AND gdp.year = em.year
LEFT JOIN cons_data cons ON gdp.country = cons.country AND gdp.year = cons.year
LEFT JOIN prod_data prod ON gdp.country = prod.country AND gdp.year = prod.year;

-- Per capita emissions
SELECT
  em.country,
  em.year,
  em.emission / pop.population_value AS emissions_per_capita
FROM emission_3 em
JOIN population pop USING(country, year);

SELECT 
    e.country,
    SUM(e.emission) AS total_emission,
    SUM(p.population_value) AS total_population,
    ROUND(SUM(e.emission) / SUM(p.population_value), 3) AS per_capita_emission
FROM emission_3 e
JOIN population p ON e.country = p.country AND e.year = p.year
GROUP BY e.country
HAVING total_emission IS NOT NULL AND total_population IS NOT NULL
ORDER BY per_capita_emission ASC;

-- Emissions per GDP unit
SELECT 
    e.country,
    e.year,
    e.energy_type,
    e.emission / g.gdp_value AS emissions_per_gdp
FROM emission_3 e
JOIN gdp_3 g 
  ON e.country = g.country AND e.year = g.year;

-- Emissions per GDP unit
SELECT 
    e.country,
    SUM(e.emission) AS total_emission,
    SUM(g.gdp_value) AS gdp_value,
    ROUND(SUM(e.emission) / SUM(g.gdp_value), 3) AS emissions_per_gdp
FROM emission_3 e
JOIN gdp_3 g 
  ON e.country = g.country AND e.year = g.year
GROUP BY e.country
HAVING total_emission IS NOT NULL AND gdp_value IS NOT NULL
ORDER BY emissions_per_gdp DESC;

/* Analysis Questions
3.a Trends in energy consumption, production, and emissions
3.b Economic development trends (GDP growth vs. energy demand) 
3.c Countries that are reducing emissions while increasing GDP – signs of green growth
*/

-- Trends in energy consumption, production, and emissions
SELECT 
    cons.year,
    SUM(cons.consumption) AS global_consumption,
    SUM(prod.production) AS global_production,
    SUM(em.emission) AS global_emissions
FROM consumption cons
JOIN production prod ON cons.country = prod.country AND cons.year = prod.year
JOIN emission_3 em ON cons.country = em.country AND cons.year = em.year
GROUP BY cons.year
ORDER BY cons.year;

-- Economic development trends (GDP growth vs. energy demand)
SELECT 
    g.year,
    SUM(g.gdp_value) AS global_gdp,
    SUM(cons.consumption) AS global_energy_consumption
FROM gdp_3 g
JOIN consumption cons ON g.country = cons.country AND g.year = cons.year
GROUP BY g.year
ORDER BY g.year;

/* Analysis Questions
4.a Whether a country is an energy importer or exporter by comparing its production vs. consumption. 
4.b Which countries are the top energy consumers but have low emissions per capita?
*/

-- Whether a country is an energy importer or exporter by comparing its production vs. consumption.
SELECT 
    c.country,
    SUM(prod.production) AS total_production,
    SUM(cons.consumption) AS total_consumption,
    CASE 
        WHEN SUM(prod.production) > SUM(cons.consumption) THEN 'Exporter'
        WHEN SUM(prod.production) < SUM(cons.consumption) THEN 'Importer'
        ELSE 'Balanced'
    END AS energy_status
FROM country c
JOIN production prod ON c.country = prod.country
JOIN consumption cons ON c.country = cons.country AND prod.year = cons.year
GROUP BY c.country
ORDER BY energy_status;