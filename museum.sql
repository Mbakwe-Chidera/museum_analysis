--inspect tables
select * from artist

select * from canvas_size

select * from museum

select * from museum_hours

select * from product_size

select * from subject

select * from work

--DATA CLEANING
--checking for missing values in each table
SELECT *
from artist where artist_id IS NULL OR Names IS NULL OR nationality IS NULL OR style IS NULL OR birth IS NULL or death IS NULL;
--no null values

--checking for duplicates
SELECT *
from artist GROUP BY artist_id, Names, nationality, style, birth, death
HAVING COUNT(*) > 1;
--no duplicates

SELECT *
from canvas_size where size_id IS NULL OR width IS NULL OR height IS NULL OR label IS NULL;
--no null values

-- checking for duplicates
SELECT *
from canvas_size GROUP BY size_id, width, height, label
HAVING COUNT(*) > 1;
--no duplicates

SELECT *
from museum where museum_id IS NULL OR Name IS NULL OR address IS NULL OR city IS NULL OR country IS NULL or phone IS NULL OR url IS NULL;
-- no null values 

-- checking for duplicate values
SELECT *
from museum 
GROUP BY museum_id, Name, address, city, country, phone, url
HAVING COUNT(*) > 1;
--no duplicates

SELECT *
from museum_hours where museum_id IS NULL OR day IS NULL OR [open] IS NULL OR [close] IS NULL;
--no null values

--checking for duplicates
SELECT *
from museum_hours
GROUP BY museum_id, day, [open], [close]
HAVING COUNT(*) > 1;

--there was record of 1 duplicate and we will remove it with a CTE function
WITH CTE AS (
    SELECT museum_id, day, [open], [close],
           ROW_NUMBER() OVER(PARTITION BY museum_id, day, [open], [close] ORDER BY museum_id) AS RowNum
    FROM museum_hours
)
DELETE FROM CTE WHERE RowNum > 1;


SELECT *
from product_size where work_id IS NULL OR size_id IS NULL OR sales_price IS NULL OR regular_price IS NULL;
-- no null values
-- checking for duplicates
SELECT *
from product_size 
GROUP BY work_id, size_id, sales_price, regular_price
HAVING COUNT(*) > 1;
--duplicates were found and would be removed with cte
WITH CTE AS (
    SELECT work_id, size_id, sales_price, regular_price,
           ROW_NUMBER() OVER(PARTITION BY work_id, size_id, sales_price, regular_price ORDER BY work_id) AS RowNum
    FROM product_size
)
DELETE FROM CTE WHERE RowNum > 1;


SELECT *
from subject where work_id IS NULL OR subject IS NULL;
--no null values
--checking for duplicate values
SELECT *
from subject 
GROUP BY work_id, subject
HAVING COUNT(*) > 1;
--it has duplicate columns but i dont think it is necessary to drop them

SELECT *
from work where work_id IS NULL OR Name IS NULL OR artist_id IS NULL OR style IS NULL OR museum_id IS NULL;
-- it has null values, Update the missing values in the style column with the most frequent style
UPDATE work
SET style = (
    SELECT TOP 1 style
    FROM work
    WHERE style IS NOT NULL
    GROUP BY style
    ORDER BY COUNT(*) DESC
)
WHERE style IS NULL;

-- Update missing museum IDs with a placeholder value (0)
UPDATE work
SET museum_id = 0
WHERE museum_id IS NULL;





--check for duplicates
SELECT work_id, Name, artist_id, style, museum_id, COUNT(*) AS duplicate_count
FROM work
GROUP BY work_id, Name, artist_id, style, museum_id
HAVING COUNT(*) > 1;
--it has duplicates, it will be removed using cte
WITH CTE AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY work_id, Name, artist_id, style, museum_id ORDER BY work_id) AS RowNum
    FROM work
)
DELETE FROM CTE WHERE RowNum > 1;


-- lets go straing to gaining insights from the data and answer some questions 

-- 1. Fetch all the paintings which are not displayed on any museums?
SELECT *
FROM product_size
WHERE work_id NOT IN (
    SELECT DISTINCT work_id
    FROM museum
);
-- all paintings were displayed in the museum

--2. Are there museums without any paintings?
SELECT *
FROM museum
WHERE museum_id NOT IN (
    SELECT DISTINCT museum_id
    FROM product_size
);
--there is no museum without painting

--3. How many paintings have an asking price of more than their regular price?
SELECT COUNT(*) AS paintings_with_higher_sales_price
FROM product_size
WHERE sales_price > regular_price;

--4. Identify the paintings whose asking price is less than 50% of its regular price
SELECT *
FROM product_size
WHERE sales_price < 0.5 * regular_price;

--5. Which canva size costs the most?
SELECT TOP 5 cs.size_id, cs.label, ps.sales_price
FROM canvas_size cs
JOIN product_size ps ON cs.size_id = ps.size_id
ORDER BY ps.sales_price DESC;

--6. Fetch the top 10 most famous painting subject
SELECT TOP 10 subject, COUNT(*) AS subject_count
FROM subject
GROUP BY subject
ORDER BY COUNT(*) DESC;

--7. Identify the museums which are open on both Sunday and Monday. Display museum name, city.
SELECT m.Name, m.city
FROM museum_hours mh1
JOIN museum_hours mh2 ON mh1.museum_id = mh2.museum_id
JOIN museum m ON mh1.museum_id = m.museum_id
WHERE mh1.day = 'Sunday'
  AND mh2.day = 'Monday';

--8. How many museums are open every single day?
SELECT m.Name, m.city
FROM museum_hours mh
JOIN museum m ON mh.museum_id = m.museum_id
GROUP BY mh.museum_id, m.Name, m.city
HAVING COUNT(DISTINCT mh.day) = 7;

--9. Which are the top 5 most popular museum? (Popularity is defined based on most no of paintings in a museum)
SELECT TOP 5 m.Name AS museum_name, m.city, COUNT(ps.work_id) AS num_paintings
FROM museum m
LEFT JOIN work w ON m.museum_id = w.museum_id
LEFT JOIN product_size ps ON w.work_id = ps.work_id
GROUP BY m.museum_id, m.Name, m.city
ORDER BY num_paintings DESC;

--10. Who are the top 5 most popular artist? (Popularity is defined based on most no of paintings done by an artist)
SELECT TOP 5 a.Names AS artist_name, COUNT(w.work_id) AS num_paintings
FROM artist a
LEFT JOIN work w ON a.artist_id = w.artist_id
GROUP BY a.artist_id, a.Names
ORDER BY num_paintings DESC;

--11. Display the 3 least popular canva sizes
SELECT TOP 3 cs.size_id, cs.width, cs.height, cs.label, COUNT(ps.work_id) AS num_paintings
FROM canvas_size cs
LEFT JOIN product_size ps ON cs.size_id = ps.size_id
GROUP BY cs.size_id, cs.width, cs.height, cs.label
ORDER BY num_paintings ASC;

--12. Which museum is open for the longest during a day. Dispay museum name, state and hours open and which day?
SELECT TOP 5 m.Name AS museum_name, m.city,
       mh.day,
       mh.[open] AS opening_time,
       mh.[close] AS closing_time,
       (CASE 
            WHEN mh.[open] LIKE '__:__:_%' AND mh.[close] LIKE '__:__:_%' THEN
                (CONVERT(INT, LEFT(mh.[close], 2)) * 60 + CONVERT(INT, SUBSTRING(mh.[close], 4, 2))) -
                (CONVERT(INT, LEFT(mh.[open], 2)) * 60 + CONVERT(INT, SUBSTRING(mh.[open], 4, 2)))
            ELSE
                NULL -- Handle invalid time formats
        END) AS duration_minutes
FROM museum m
JOIN museum_hours mh ON m.museum_id = mh.museum_id
ORDER BY duration_minutes DESC;

--13. Which museum has the most no of most popular painting style?
SELECT TOP 5 m.Name AS museum_name, m.city, 
       COUNT(DISTINCT w.style) AS popular_style_count
FROM museum m
JOIN work w ON m.museum_id = w.museum_id
GROUP BY m.Name, m.city
ORDER BY popular_style_count DESC;


--14. Identify the artists whose paintings are displayed in multiple countries
SELECT TOP 5 a.Names AS artist_name,
       COUNT(DISTINCT m.country) AS countries_displayed_in
FROM artist a
JOIN work w ON a.artist_id = w.artist_id
JOIN museum m ON w.museum_id = m.museum_id
GROUP BY a.Names
HAVING COUNT(DISTINCT m.country) > 1
ORDER BY countries_displayed_in DESC;

--15. Display the country and the city with most no of museums. 
SELECT TOP 5 m.country, m.city, COUNT(*) AS museum_count
FROM museum m
GROUP BY m.country, m.city
ORDER BY COUNT(*) DESC;

--16. Identify the artist and the museum where the most expensive and least expensive painting is placed. 
--Display the artist name, sale_price, painting name, museum name, museum city and canvas label
--Most Expensive
SELECT *
FROM (
    -- Most Expensive Painting
    SELECT TOP 2
        'Most Expensive' AS type,
        w.Name AS painting_name,
        ps.sales_price,
        a.Names AS artist_name,
        m.Name AS museum_name,
        m.city,
        cs.label
    FROM work w
    JOIN artist a ON w.artist_id = a.artist_id
    JOIN product_size ps ON w.work_id = ps.work_id
    JOIN canvas_size cs ON ps.size_id = cs.size_id
    JOIN museum m ON w.museum_id = m.museum_id
    ORDER BY ps.sales_price DESC

    UNION ALL

    -- Least Expensive Painting
    SELECT TOP 2
        'Least Expensive' AS type,
        w.Name AS painting_name,
        ps.sales_price,
        a.Names AS artist_name,
        m.Name AS museum_name,
        m.city,
        cs.label
    FROM work w
    JOIN artist a ON w.artist_id = a.artist_id
    JOIN product_size ps ON w.work_id = ps.work_id
    JOIN canvas_size cs ON ps.size_id = cs.size_id
    JOIN museum m ON w.museum_id = m.museum_id
    ORDER BY ps.sales_price ASC
) AS combined_results;

--17. Which country has the 5th highest no of paintings?
SELECT country
FROM (
    SELECT m.country, ROW_NUMBER() OVER (ORDER BY COUNT(*) DESC) AS country_rank
    FROM museum m
    JOIN work w ON m.museum_id = w.museum_id
    GROUP BY m.country
) AS ranked_countries
WHERE country_rank = 5;

--18. Which are the 3 most popular and 3 least popular painting styles?
-- Combine results of most and least popular painting styles
SELECT style, style_count, 'Most Popular' AS popularity
FROM (
    SELECT TOP 3 style, COUNT(*) AS style_count
    FROM work
    GROUP BY style
    ORDER BY style_count DESC
) AS most_popular

UNION ALL

SELECT style, style_count, 'Least Popular' AS popularity
FROM (
    SELECT TOP 3 style, COUNT(*) AS style_count
    FROM work
    GROUP BY style
    ORDER BY style_count ASC
) AS least_popular
ORDER BY style_count DESC;


--19. Which artist has the most no of Portraits paintings outside USA?.
-- Display artist name, no of paintings and the artist nationality.
SELECT TOP 2 a.Names AS artist_name,
       a.nationality AS artist_nationality,
       COUNT(*) AS num_paintings
FROM work w
JOIN artist a ON w.artist_id = a.artist_id
JOIN museum m ON w.museum_id = m.museum_id
JOIN subject s ON w.work_id = s.work_id
WHERE s.subject = 'Portraits'
  AND m.country <> 'USA'
GROUP BY a.Names, a.nationality
ORDER BY num_paintings DESC;

--20.Total number of painting
SELECT COUNT(*) AS total_paintings
FROM work;

--21. Total Revenue
SELECT SUM(sales_price) AS total_revenue
FROM product_size;

--23. Total Museum
SELECT COUNT(DISTINCT museum_id) AS total_museums
FROM museum;

--24. Total countries
SELECT COUNT(DISTINCT country) AS total_countries
FROM museum;

--25.Total Artist
SELECT COUNT(DISTINCT artist_id) AS total_artists
FROM artist;


-- 26. Calculate the average duration in minutes
SELECT AVG(duration_minutes) AS average_duration_minutes
FROM (
    SELECT TOP 5 m.Name AS museum_name, m.city,
           mh.day,
           mh.[open] AS opening_time,
           mh.[close] AS closing_time,
           (CASE 
                WHEN mh.[open] LIKE '__:__:_%' AND mh.[close] LIKE '__:__:_%' THEN
                    (CONVERT(INT, LEFT(mh.[close], 2)) * 60 + CONVERT(INT, SUBSTRING(mh.[close], 4, 2))) -
                    (CONVERT(INT, LEFT(mh.[open], 2)) * 60 + CONVERT(INT, SUBSTRING(mh.[open], 4, 2)))
                ELSE
                    NULL -- Handle invalid time formats
            END) AS duration_minutes
    FROM museum m
    JOIN museum_hours mh ON m.museum_id = mh.museum_id
    ORDER BY duration_minutes DESC
) AS subquery;











