--SELECT *
--FROM PortfolioProject..CovidDeaths
--WHERE continent IS NOT NULL AND continent != ''
--ORDER BY 3, 4;

--SELECT *
--FROM PortfolioProject..CovidVaccinations
--WHERE continent IS NOT NULL AND continent != ''
--ORDER BY 3, 4;




SELECT location, CAST(date AS DATE) AS date, total_cases, new_cases, total_deaths, population 
FROM PortfolioProject..CovidDeaths
WHERE TRY_CAST(date AS DATE) IS NOT NULL AND continent IS NOT NULL AND continent != ''
ORDER BY 1, 2;




-- TOTAL CASES vs. TOTAL DEATHS 
-- SHOWS LIKELIHOOD OF DYING IF YOU CONTRACT COVID IN YOUR COUNTRY
SELECT location, CAST(date AS DATE) AS date, total_cases, total_deaths, (CAST(total_deaths AS float) / CAST(total_cases AS float))*100 AS DeathPercentage 
FROM PortfolioProject..CovidDeaths
WHERE TRY_CAST(date AS DATE) IS NOT NULL 
	AND location LIKE '%states%' 
	AND continent IS NOT NULL
	AND continent != ''
ORDER BY 1, 2;




-- TOTAL CASES vs. POPULATION
-- SHOWS WHAT PERCENTAGE OF POPULATION GOT COVID
SELECT location, CAST(date AS DATE) AS date, population , total_cases, 
	(TRY_CAST(total_cases AS decimal(20, 2)) / TRY_CAST(population AS decimal(20, 2)))*100 AS PercentPopulationInfected 
FROM PortfolioProject..CovidDeaths
WHERE 
	TRY_CAST(date AS DATE) IS NOT NULL 
	AND TRY_CAST(population AS decimal(20, 2)) IS NOT NULL
    AND TRY_CAST(total_cases AS decimal(20, 2)) IS NOT NULL
    AND TRY_CAST(population AS decimal(20, 2)) <> 0
	AND continent IS NOT NULL
	AND continent != ''
ORDER BY 1, 2;




-- LOOKING AT COUNTRIES WITH HIGHEST INFECTION RATE COMPARED TO POPULATION
SELECT location, population, MAX(total_cases) AS HighestInfectionCount,
	MAX((TRY_CAST(total_cases AS decimal(20, 2)) / TRY_CAST(population AS decimal(20, 2)))*100) AS PercentPopulationInfected
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL 
GROUP BY location, population
ORDER BY PercentPopulationInfected DESC;




-- SHOWING THE COUNTRIES WITH HIGHEST DEATH COUNT PER POPULATION
SELECT location, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount 
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL AND continent != ''
GROUP BY location
ORDER BY TotalDeathCount DESC;




-- SHOWING THE CONTINENTS WITH HIGHEST DEATH COUNT PER POPULATION
SELECT continent, MAX(CAST(total_deaths AS INT)) AS TotalDeathCount 
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL AND continent != ''
GROUP BY continent
ORDER BY TotalDeathCount DESC;




-- GLOBAL NUMBERS
SELECT TRY_CAST(date AS DATE) AS date, SUM(CAST(new_cases AS FLOAT)) AS total_cases, SUM(CAST(new_deaths AS FLOAT)) AS total_deaths, 
	CASE WHEN SUM(CAST(new_cases AS FLOAT)) = 0 THEN 0
	ELSE (SUM(CAST(new_deaths AS FLOAT)) / SUM(CAST(new_cases AS FLOAT)))*100 END AS DeathPercentage 
FROM PortfolioProject..CovidDeaths
WHERE TRY_CAST(date AS DATE) IS NOT NULL
	AND continent IS NOT NULL
	AND continent != ''
GROUP BY TRY_CAST(date AS DATE) 
ORDER BY 1, 2;

SELECT SUM(CAST(new_cases AS FLOAT)) AS total_cases, SUM(CAST(new_deaths AS FLOAT)) AS total_deaths, 
	CASE WHEN SUM(CAST(new_cases AS FLOAT)) = 0 THEN 0
	ELSE (SUM(CAST(new_deaths AS FLOAT)) / SUM(CAST(new_cases AS FLOAT)))*100 END AS DeathPercentage 
FROM PortfolioProject..CovidDeaths
WHERE continent IS NOT NULL
	AND continent != ''
ORDER BY 1, 2;




-- LOOKING AT TOTAL POPULATION VS. VACCINATIONS
SELECT dea.continent, dea.location, TRY_CAST(dea.date AS DATE) AS date, dea.population, vac.new_vaccinations, 
	SUM(CONVERT(INT, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location, TRY_CAST(dea.date AS DATE)) AS RollingPeopleVaccinated
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
	ON dea.location = vac.location AND TRY_CAST(dea.date AS DATE) = TRY_CAST(vac.date AS DATE) 
WHERE dea.continent IS NOT NULL AND dea.continent != ''
ORDER BY 2, 3;




-- USING CTE 
WITH PopVsVac AS (
SELECT dea.continent, dea.location, TRY_CAST(dea.date AS DATE) AS date, dea.population, vac.new_vaccinations, 
	SUM(CONVERT(INT, vac.new_vaccinations)) OVER (PARTITION BY dea.location ORDER BY dea.location, TRY_CAST(dea.date AS DATE)) AS RollingPeopleVaccinated
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
	ON dea.location = vac.location AND TRY_CAST(dea.date AS DATE) = TRY_CAST(vac.date AS DATE) 
WHERE dea.continent IS NOT NULL AND dea.continent != ''
)
SELECT *, CASE WHEN CAST(population AS INT) = 0 THEN 0 ELSE (CAST(RollingPeopleVaccinated AS FLOAT)/CAST(population AS FLOAT))*100 END AS PercentRollingPeopleVaccinated
FROM PopVsVac;




-- USING TEMP TABLE
DROP TABLE IF EXISTS #PercentPopulationVaccinated;
CREATE TABLE #PercentPopulationVaccinated
(
    Continent NVARCHAR(255),
    Location NVARCHAR(255),
    Date DATETIME,
    Population NUMERIC,
    New_vaccinations NUMERIC,
    RollingPeopleVaccinated NUMERIC
);

INSERT INTO #PercentPopulationVaccinated
SELECT 
    dea.continent, 
    dea.location, 
    TRY_CAST(dea.date AS DATE) AS date, 
    TRY_CAST(dea.population AS NUMERIC) AS population, 
    TRY_CAST(vac.new_vaccinations AS NUMERIC) AS new_vaccinations, 
    SUM(CONVERT(INT, TRY_CAST(vac.new_vaccinations AS NUMERIC))) OVER (
        PARTITION BY dea.location 
        ORDER BY dea.location, TRY_CAST(dea.date AS DATE)
    ) AS RollingPeopleVaccinated
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
    ON dea.location = vac.location 
    AND TRY_CAST(dea.date AS DATE) = TRY_CAST(vac.date AS DATE)
WHERE dea.continent IS NOT NULL 
    AND dea.continent != ''
    AND TRY_CAST(dea.population AS NUMERIC) IS NOT NULL
    AND TRY_CAST(vac.new_vaccinations AS NUMERIC) IS NOT NULL;

SELECT *, 
       CASE 
           WHEN population = 0 THEN 0 
           ELSE (CAST(RollingPeopleVaccinated AS FLOAT)/CAST(population AS FLOAT)) * 100 
       END AS PercentRollingPeopleVaccinated
FROM #PercentPopulationVaccinated;




--- CREATING VIEW TO STORE DATA FOR LATER VISUALIZATIONS
CREATE VIEW PercentPopulationVaccinated AS
SELECT 
    dea.continent, 
    dea.location, 
    TRY_CAST(dea.date AS DATE) AS date, 
    TRY_CAST(dea.population AS NUMERIC) AS population, 
    TRY_CAST(vac.new_vaccinations AS NUMERIC) AS new_vaccinations, 
    SUM(CONVERT(INT, TRY_CAST(vac.new_vaccinations AS NUMERIC))) OVER (
        PARTITION BY dea.location 
        ORDER BY dea.location, TRY_CAST(dea.date AS DATE)
    ) AS RollingPeopleVaccinated
FROM PortfolioProject..CovidDeaths dea
JOIN PortfolioProject..CovidVaccinations vac
    ON dea.location = vac.location 
    AND TRY_CAST(dea.date AS DATE) = TRY_CAST(vac.date AS DATE)
WHERE dea.continent IS NOT NULL 
    AND dea.continent != ''
    AND TRY_CAST(dea.population AS NUMERIC) IS NOT NULL
    AND TRY_CAST(vac.new_vaccinations AS NUMERIC) IS NOT NULL;

SELECT * 
FROM PercentPopulationVaccinated
;