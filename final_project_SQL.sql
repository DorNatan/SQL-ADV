-- Specify the schema
USE maven_advanced_sql;

-- PART I: SCHOOL ANALYSIS
-- 1. View the schools and school details tables
SELECT *
FROM schools;

SELECT *
FROM school_details;

-- 2. In each decade, how many schools were there that produced players?

WITH db AS (SELECT playerID, schoolID, FLOOR(yearID /10) *10 AS decade_bins
			FROM schools)

SELECT decade_bins, COUNT(schoolID) AS num_schools
FROM db
GROUP BY decade_bins
ORDER BY decade_bins DESC;

-- 3. What are the names of the top 5 schools that produced the most players?

SELECT	 sd.name_full, COUNT(DISTINCT s.playerID) AS num_players
FROM	 schools s LEFT JOIN school_details sd
		 ON s.schoolID = sd.schoolID
GROUP BY s.schoolID
ORDER BY num_players DESC
LIMIT 	 5;

-- 4. For each decade, what were the names of the top 3 schools that produced the most players?

WITH db AS (SELECT playerID, schoolID, FLOOR(yearID /10) *10 AS decade_bins
			FROM schools),

	 np AS (SELECT decade_bins, schoolID , COUNT(playerID) AS num_players,
			ROW_NUMBER() OVER (PARTITION BY decade_bins ORDER BY COUNT(playerID) DESC) AS row_n
			FROM db
			GROUP BY decade_bins, schoolID
			ORDER BY decade_bins, num_players DESC)

SELECT *
FROM np
WHERE row_n <= 3
ORDER BY decade_bins DESC, row_n;

-- PART II: SALARY ANALYSIS

-- 1. View the salaries table
SELECT *
FROM salaries;

-- 2. Return the top 20% of teams in terms of average annual spending
WITH ts AS (SELECT yearID, teamID, SUM(salary) AS total_spend
			FROM salaries
			GROUP BY yearID, teamID
			ORDER BY yearID, teamID),
            
 avg_sp AS (SELECT teamID, AVG(total_spend) avg_spend,
			NTILE(5) OVER (ORDER BY AVG(total_spend) DESC) AS spend_pct
			FROM ts
            GROUP BY teamID)

SELECT teamID ,ROUND(avg_spend / 1000000, 1) AS avg_spend_millions
FROM avg_sp
WHERE spend_pct = 1;

-- 3. For each team, show the cumulative sum of spending over the years

WITH ts AS (SELECT yearID, teamID, SUM(salary) AS total_spend
			FROM salaries
			GROUP BY yearID, teamID
			ORDER BY yearID, teamID)
            
SELECT yearID, teamID, total_spend,
	   ROUND(SUM(total_spend) OVER (PARTITION BY teamID ORDER BY yearID) / 1000000, 1 )AS cumulative_sum_millions
FROM ts;

-- 4. Return the first year that each team's cumulative spending surpassed 1 billion

WITH ts AS (SELECT yearID, teamID, SUM(salary) AS total_spend
			FROM salaries
			GROUP BY yearID, teamID
			ORDER BY yearID, teamID),
            
	csm AS (SELECT yearID, teamID, total_spend,
			   ROUND(SUM(total_spend) OVER (PARTITION BY teamID ORDER BY yearID) / 1000000, 1 )AS cumulative_sum_millions
			FROM ts),

	 rn AS (SELECT yearID, teamID, total_spend, cumulative_sum_millions,
			ROW_NUMBER() OVER(PARTITION BY teamID ORDER BY yearID) AS rnc
            FROM csm
            WHERE cumulative_sum_millions >= 1000)
            
SELECT	teamID, yearID, ROUND(cumulative_sum_millions / 1000, 2) AS cumulative_sum_billions
FROM	rn
WHERE	rnc = 1;


-- PART III: PLAYER CAREER ANALYSIS

-- TASK 1: View the players table and find the number of players in the table
SELECT *
FROM players;
SELECT COUNT(*) FROM players;

-- TASK 2: For each player, calculate their age at their first (debut) game, their last game,
-- and their career length (all in years). Sort from longest career to shortest career. [Datetime Functions]
WITH bd AS (SELECT playerID, CAST(CONCAT(birthYear, '-', birthMonth, '-', birthDay) AS DATE) AS birthdate
			FROM players)

SELECT 
	   TIMESTAMPDIFF(YEAR, bd.birthdate,debut) AS starting_age,
	   TIMESTAMPDIFF(YEAR, bd.birthdate, finalGame) AS ending_age,
	   TIMESTAMPDIFF(YEAR, debut, finalGame) AS career_length
FROM players
	INNER JOIN bd
    ON players.playerID = bd.playerID
ORDER BY career_length DESC;

-- TASK 3: What team did each player play on for their starting and ending years? [Joins]
SELECT p.playerID, s.yearID AS starting_year, s.teamID AS starting_team,
e.yearID AS ending_year, e.teamID AS ending_team
FROM players AS p
	INNER JOIN salaries AS s
	ON s.playerID = p.playerID
	AND s.yearID = YEAR(p.debut)
    INNER JOIN salaries AS e
    ON e.playerID = p.playerID
	AND e.yearID = YEAR(p.finalGame);
    
-- TASK 4: How many players started and ended on the same team and also played for over a decade? [Basics]
SELECT 	p.nameGiven,
		s.yearID AS starting_year, s.teamID AS starting_team,
        e.yearID AS ending_year, e.teamID AS ending_team
FROM	players p INNER JOIN salaries s
							ON p.playerID = s.playerID
							AND YEAR(p.debut) = s.yearID
				  INNER JOIN salaries e
							ON p.playerID = e.playerID
							AND YEAR(p.finalGame) = e.yearID
WHERE	s.teamID = e.teamID AND e.yearID - s.yearID > 10;


-- PART IV: PLAYER COMPARISON ANALYSIS

-- TASK 1: View the players table
SELECT * FROM players;

-- TASK 2: Which players have the same birthday? Hint: Look into GROUP_CONCAT / LISTAGG / STRING_AGG [String Functions]
WITH bn AS (SELECT	CAST(CONCAT(birthYear, '-', birthMonth, '-', birthDay) AS DATE) AS birthdate,
					nameGiven
			FROM	players)

SELECT	birthdate, GROUP_CONCAT(nameGiven SEPARATOR ', ') AS players
FROM	bn
WHERE	YEAR(birthdate) BETWEEN 1980 AND 1990
GROUP BY birthdate
ORDER BY birthdate;

-- TASK 3: Create a summary table that shows for each team, what percent of players bat right, left and both [Pivoting]
WITH up AS (SELECT DISTINCT s.teamID, s.playerID, p.bats
           FROM salaries s LEFT JOIN players p
           ON s.playerID = p.playerID) -- unique players CTE

SELECT teamID,
		ROUND(SUM(CASE WHEN bats = 'R' THEN 1 ELSE 0 END) / COUNT(playerID) * 100, 1) AS bats_right,
        ROUND(SUM(CASE WHEN bats = 'L' THEN 1 ELSE 0 END) / COUNT(playerID) * 100, 1) AS bats_left,
        ROUND(SUM(CASE WHEN bats = 'B' THEN 1 ELSE 0 END) / COUNT(playerID) * 100, 1) AS bats_both
FROM up
GROUP BY teamID;

-- TASK 4: How have average height and weight at debut game changed over the years, and what's the decade-over-decade difference? [Window Functions]
WITH hw AS (SELECT	FLOOR(YEAR(debut) / 10) * 10 AS decade,
					AVG(height) AS avg_height, AVG(weight) AS avg_weight
			FROM	players
			GROUP BY decade)
            
SELECT	decade,
		avg_height - LAG(avg_height) OVER(ORDER BY decade) AS height_diff,
        avg_weight - LAG(avg_weight) OVER(ORDER BY decade) AS weight_diff
FROM	hw
WHERE	decade IS NOT NULL;