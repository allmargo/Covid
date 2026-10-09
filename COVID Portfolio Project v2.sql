ALTER TABLE "CovidDeaths"
ALTER COLUMN date TYPE DATE
USING TO_DATE(date, 'DD.MM.YYYY');

SELECT *
FROM "CovidDeaths" cd 
ORDER BY location, date; 

ALTER TABLE "CovidVaccination"
ALTER COLUMN date TYPE DATE
USING TO_DATE(date, 'DD.MM.YYYY');

SELECT *
FROM "CovidVaccination" cv
ORDER BY location, date; 

-- выберем данные, которые будем использовать

SELECT location, date, total_cases, new_cases, total_deaths, population
FROM "CovidDeaths"
ORDER BY location, date;

-- сравним общее число заражений и число смертей от ковида
-- вероятность смерти при заражении ковидом в России

SELECT location, date, total_cases, total_deaths, 
       (total_deaths::NUMERIC / total_cases)*100 as death_percentage 
FROM "CovidDeaths"
WHERE location = 'Russia'
ORDER BY location, date;

-- общее количество случаев заражения по отношению к населению
-- какой процент населения заболел ковидом

SELECT location, date, population, total_cases, 
       (total_cases::NUMERIC / population)*100 as percent_population_infected
FROM "CovidDeaths"
WHERE location = 'Russia'
ORDER BY location, date;


-- РАЗОБЬЁМ ПО КОНТИНЕНТАМ

-- континенты с самым высоким числом смертей

SELECT continent, MAX(total_deaths) as total_death_count
FROM "CovidDeaths"
WHERE continent IS NOT NULL
GROUP BY continent
HAVING MAX(total_deaths) IS NOT NULL
ORDER BY total_death_count DESC;


-- ЗАПРОСЫ ДЛЯ TABLEAU

-- 1. ГЛОБАЛЬНЫЕ ПОКАЗАТЕЛИ

SELECT SUM(new_cases) as total_cases, 
       SUM(new_deaths) as total_deaths, 
       SUM(new_deaths) / SUM(new_cases)*100 as death_percentage 
FROM "CovidDeaths"
-- WHERE location = 'Russia'
WHERE continent IS NOT NULL
-- GROUP BY date
ORDER BY total_cases, total_deaths;

-- Проверим получившиеся данные. В следующем и в предыдущем запросах показатели близки по значению, но не одинаковы. Второй запрос включает локацию "International"
--SELECT SUM(new_cases) as total_cases, 
--       SUM(new_deaths) as total_deaths, 
--       SUM(new_deaths) / SUM(new_cases)*100 as death_percentage 
--FROM "CovidDeaths"
----WHERE location = 'Russia'
--WHERE location = 'World'
----GROUP BY date
--ORDER BY total_cases, total_deaths;



-- 2. Страны с самым высоким числом смертей на душу населения
-- в предыдущие запросы не входят некоторые локации, поэтому мы исключим их для сохранения единообразия. Европейский союз - часть Европы

SELECT location, SUM(new_deaths::NUMERIC) as total_death_count
FROM "CovidDeaths"
WHERE continent IS NULL
      AND location NOT IN ('World', 'European Union', 'International')
GROUP BY location
ORDER BY total_death_count DESC;


-- 3. Посмотрим на страны с самым высоким уровнем заражения по отношению к населению

SELECT * FROM (
    SELECT location, population, 
           MAX(total_cases) as highest_infection_count, 
           MAX((total_cases::NUMERIC / population)*100) as percent_population_infected
    FROM "CovidDeaths"
    GROUP BY location, population
) t
ORDER BY percent_population_infected DESC;

-- 4. 

SELECT * FROM (
    SELECT location, population, date,
           MAX(total_cases) as highest_infection_count, 
           MAX((total_cases::NUMERIC / population)) * 100 as percent_population_infected
    FROM "CovidDeaths"
    GROUP BY location, population, date
) t
ORDER BY percent_population_infected DESC;

-- сравним общую численность населения с вакцинацией

SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(vac.new_vaccinations::NUMERIC) OVER (Partition by dea.location ORDER BY dea.date) as rolling_people_vaccinated
-- , (rolling_people_vaccinated / population) * 100
FROM "CovidDeaths" dea
JOIN "CovidVaccination" vac 
     ON dea.location = vac."location" 
     AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
ORDER BY dea.location, dea.date;

-- воспользуемся CTE 

WITH pop_vs_vac AS (
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(vac.new_vaccinations::NUMERIC) OVER (Partition by dea.location ORDER BY dea.date) as rolling_people_vaccinated
-- , (rolling_people_vaccinated / population) * 100
FROM "CovidDeaths" dea
JOIN "CovidVaccination" vac 
     ON dea.location = vac."location" 
     AND dea.date = vac.date
WHERE dea.continent IS NOT NULL
-- ORDER BY dea.location, dea.date
)
SELECT *, (rolling_people_vaccinated / population) * 100 as rolling_people_vaccinated_percent
FROM pop_vs_vac;



-- ВРЕМЕННАЯ ТАБЛИЦА

DROP TABLE IF EXISTS "PercentPopulationVaccinated";

CREATE TABLE "PercentPopulationVaccinated"
(
continent VARCHAR(255),
location VARCHAR(255),
date TIMESTAMP,
population NUMERIC,
new_vaccinations NUMERIC,
rolling_people_vaccinated NUMERIC
);

INSERT INTO "PercentPopulationVaccinated"
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(vac.new_vaccinations::NUMERIC) OVER (Partition by dea.location ORDER BY dea.date) as rolling_people_vaccinated
-- , (rolling_people_vaccinated / population) * 100
FROM "CovidDeaths" dea
JOIN "CovidVaccination" vac 
     ON dea.location = vac."location" 
     AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;

SELECT *, (rolling_people_vaccinated / population) * 100 as percent_population_vaccinated
FROM "PercentPopulationVaccinated";


-- создадим представление (view) для хранения данных для построения визуализаций

CREATE VIEW "PopulationVaccinationRate" AS
SELECT dea.continent, dea.location, dea.date, dea.population, vac.new_vaccinations
, SUM(vac.new_vaccinations::NUMERIC) OVER (Partition by dea.location ORDER BY dea.date) as rolling_people_vaccinated
-- , (rolling_people_vaccinated / population) * 100
FROM "CovidDeaths" dea
JOIN "CovidVaccination" vac 
     ON dea.location = vac."location" 
     AND dea.date = vac.date
WHERE dea.continent IS NOT NULL;