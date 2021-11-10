
-- CREACION DE TABLAS

CREATE TABLE IF NOT EXISTS YEAR (
  year INT PRIMARY KEY,
  isLeap BOOLEAN NOT NULL
);

CREATE TABLE IF NOT EXISTS SEMESTER (
  semester INT CHECK(semester = 1 OR semester = 2),
  year INT,
  PRIMARY KEY (semester, year),
  FOREIGN KEY (year) REFERENCES YEAR
);

CREATE TABLE IF NOT EXISTS QUARTER (
  quarter INT CHECK(quarter BETWEEN 1 AND 4),
  semester INT NOT NULL,
  year INT,
  PRIMARY KEY (quarter, year),
  UNIQUE (semester, quarter, year),
  FOREIGN KEY (semester, year) REFERENCES SEMESTER(semester, year)
);

CREATE TABLE IF NOT EXISTS MONTH (
  month INT CHECK(month BETWEEN 1 AND 12),
  quarter INT NOT NULL,
  year INT,
  month_name TEXT NOT NULL CHECK(month_name LIKE 'enero' OR month_name LIKE 'febrero' OR month_name LIKE 'marzo' OR month_name LIKE 'abril' OR month_name LIKE 'mayo' OR month_name LIKE 'junio' OR month_name LIKE 'julio' OR month_name LIKE 'agosto' OR month_name LIKE 'septiembre' OR month_name LIKE 'octubre' OR month_name LIKE 'noviembre' OR month_name LIKE 'diciembre'),
  PRIMARY KEY (month, year),
  UNIQUE (quarter, month, year),
  FOREIGN KEY (quarter, year) REFERENCES QUARTER(quarter, year)
);

CREATE TABLE IF NOT EXISTS DAY (
  ID SERIAL,
  ID_text TEXT NOT NULL,
  day_t INT CHECK (day_t BETWEEN 1 AND 31) NOT NULL,
  month INT NOT NULL,
  year INT NOT NULL,
  day_name TEXT NOT NULL CHECK(day_name LIKE 'lunes' OR day_name LIKE 'martes' OR day_name LIKE 'miercoles' OR day_name LIKE 'jueves' OR day_name LIKE 'viernes' OR day_name LIKE 'sabado' OR day_name LIKE 'domingo'),
  isWeekend BOOLEAN NOT NULL,
  PRIMARY KEY(id),
  UNIQUE (ID_text),
  UNIQUE (day_t, month, year),
  FOREIGN KEY(month, year) REFERENCES MONTH(month, year)
);

CREATE TABLE IF NOT EXISTS DEFINITIVA (
  ID INT NOT NULL,
  Year_Birth INT NOT NULL,
  Education TEXT NOT NULL,
  Marital_Status TEXT NOT NULL,
  Income INT,
  Kidhome INT NOT NULL,
  Teenhome INT NOT NULL,
  Dt_Customer TEXT NOT NULL,  --trigger to insert
  Recency INT NOT NULL,
  MntWines INT NOT NULL,
  MntFruits INT NOT NULL,
  MntMeatProducts INT NOT NULL,
  MntFishProducts INT NOT NULL,
  MntSweetProducts INT NOT NULL,
  NumDealsPurchases INT NOT NULL,
  NumWebPurchases INT NOT NULL,
  NumCatalogPurchases INT NOT NULL,
  NumStorePurchases INT NOT NULL,
  FOREIGN KEY(Dt_Customer) REFERENCES DAY(ID_text),
  PRIMARY KEY(ID)
);

-- CODIGO TRIGGERS

CREATE OR REPLACE FUNCTION isLeap(IN year INTEGER)
  RETURNS BOOLEAN as $$
  DECLARE y INTEGER;
  BEGIN
    y := year;
    RETURN (y % 4 = 0) AND (y % 100 <> 0 OR y % 400 = 0);
  END
$$ language plpgsql;

CREATE OR REPLACE FUNCTION monthName(IN month INTEGER)
  RETURNS TEXT AS $$
  DECLARE month_name TEXT;
  BEGIN
    CASE
      WHEN month = 1 THEN month_name := 'enero';
      WHEN month = 2 THEN month_name := 'febrero';
      WHEN month = 3 THEN month_name := 'marzo';
      WHEN month = 4 THEN month_name := 'abril';
      WHEN month = 5 THEN month_name := 'mayo';
      WHEN month = 6 THEN month_name := 'junio';
      WHEN month = 7 THEN month_name := 'julio';
      WHEN month = 8 THEN month_name := 'agosto';
      WHEN month = 9 THEN month_name := 'septiembre';
      WHEN month = 10 THEN month_name := 'octubre';
      WHEN month = 11 THEN month_name := 'noviembre';
      WHEN month = 12 THEN month_name := 'diciembre';
      ELSE month_name := '';
    END CASE;
    RETURN month_name;
  END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION dayName(IN day INTEGER)
  RETURNS TEXT AS $$
  DECLARE day_name TEXT;
  BEGIN
    CASE
      WHEN day = 0 THEN day_name := 'domingo';
      WHEN day = 1 THEN day_name := 'lunes';
      WHEN day = 2 THEN day_name := 'martes';
      WHEN day = 3 THEN day_name := 'miercoles';
      WHEN day = 4 THEN day_name := 'jueves';
      WHEN day = 5 THEN day_name := 'viernes';
      WHEN day = 6 THEN day_name := 'sabado';
    END CASE;
    RETURN day_name;
  END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION fillTable() RETURNS TRIGGER AS
$$
DECLARE
  auxYear YEAR.year%TYPE;
  auxSemester SEMESTER.semester%TYPE;
  auxQuarter QUARTER.quarter%TYPE;
  auxMonth MONTH.month%TYPE;
  auxDay DAY.day_t%TYPE;
  dayString TEXT;
  monthString TEXT;
  yearString TEXT;
  auxDate DATE;
  auxDayOfWeek INTEGER;
  isWeekend BOOLEAN;
  idDay DAY.ID_text%TYPE;
BEGIN

  monthString := split_part(new.Dt_Customer, '/', 1);
  dayString := split_part(new.Dt_Customer, '/', 2);
  yearString := split_part(new.Dt_Customer, '/', 3);

  auxDate := TO_DATE(new.Dt_Customer, 'MM/DD/YYYY');

  IF (monthString LIKE '' OR dayString LIKE '' OR yearString LIKE '') THEN
    RAISE EXCEPTION 'INVALID DT_CUSTOMER';
  END IF;

  auxMonth := CAST(monthString AS INT);
  auxDay := CAST(dayString AS INT);
  auxYear := CAST(yearString AS INT);

  auxSemester := (auxMonth-1)/6+1;
  auxQuarter := (auxMonth-1)/3+1;

  -- The day of the week (0 - 6; Sunday is 0)
  auxDayOfWeek := EXTRACT(DOW FROM auxDate);
  isWeekend := auxDayOfWeek = 0 OR auxDayOfWeek = 6;


  IF (NOT EXISTS(SELECT year FROM YEAR WHERE year = auxYear)) THEN
    INSERT INTO YEAR VALUES(auxYear, isLeap(auxYear));
  END IF;

  IF (NOT EXISTS(SELECT semester FROM SEMESTER WHERE semester = auxSemester AND year = auxYear)) THEN
    INSERT INTO SEMESTER VALUES(auxSemester, auxYear);
  END IF;

  IF (NOT EXISTS(SELECT quarter FROM QUARTER WHERE quarter = auxQuarter AND semester = auxSemester AND year = auxYear)) THEN
    INSERT INTO QUARTER VALUES(auxQuarter, auxSemester, auxYear);
  END IF;

  IF (NOT EXISTS(SELECT month FROM MONTH WHERE month = auxMonth AND quarter = auxQuarter AND year = auxYear)) THEN
    INSERT INTO MONTH VALUES(auxMonth, auxQuarter, auxYear, monthName(auxMonth));
  END IF;

  IF (NOT EXISTS(SELECT day_t FROM DAY WHERE day_t = auxDay AND month = auxMonth AND year = auxYear)) THEN
    idDay := (SELECT COALESCE((MAX(ID) + 1),1)::TEXT FROM DAY);
    INSERT INTO DAY(ID_text, day_t, month, year, day_name, isWeekend) VALUES(idDay, auxDay, auxMonth, auxYear, dayName(auxDayOfWeek), isWeekend);
  END IF;

  idDay := (SELECT ID_text FROM DAY WHERE day_t = auxDay AND month = auxMonth AND year = auxYear);

  new.dt_customer = idDay;

  IF (new.income IS NULL) THEN
      new.income = 0;
  END IF;
  RETURN new;
END
$$ LANGUAGE plpgsql;

CREATE TRIGGER beforeInsertDtCustomer
BEFORE INSERT ON DEFINITIVA
FOR EACH ROW
EXECUTE PROCEDURE fillTable(); -- corre un "Trigger PSM"


-- CODIGO FUNCIONES

CREATE OR REPLACE FUNCTION getAge(IN yearBirth INTEGER) RETURNS INTEGER AS $$
  BEGIN
    RETURN EXTRACT(YEAR FROM CURRENT_DATE) - yearBirth;
  END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION printData(IN currentYear INTEGER, IN typeText TEXT, IN auxText TEXT, IN recency NUMERIC, IN frecuency NUMERIC, IN monetary NUMERIC) RETURNS VOID AS $$
  BEGIN
    IF (currentYear <> -1) THEN
      RAISE NOTICE '%   % %    % % %', currentYear, typeText, auxText, recency::INTEGER, frecuency::INTEGER, monetary::INTEGER;
    ELSE
      RAISE NOTICE '----   % %    % % %', typeText, auxText, recency::INTEGER, frecuency::INTEGER, monetary::INTEGER;
    END IF;
  END
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION readCursor(IN cursor_t REFCURSOR, IN currentYear INTEGER, IN cursorType TEXT) RETURNS VOID AS $$
  DECLARE
    printYear BOOLEAN DEFAULT FALSE;
    typeText TEXT DEFAULT '';
    auxText TEXT DEFAULT '';
    i RECORD;
  BEGIN
    IF (cursorType = 'BR') THEN
      printYear := TRUE;
    END IF;
    LOOP
      FETCH cursor_t INTO i;
      EXIT WHEN NOT FOUND;
      IF (cursorType = 'BR') THEN
        typeText := 'Birth Range: ';
        CASE
          WHEN i.birth_range = '1' THEN auxText := '1) - de 25';
          WHEN i.birth_range = '2' THEN auxText := '2) de 25 a 39';
          WHEN i.birth_range = '3' THEN auxText := '3) de 40 a 49';
          WHEN i.birth_range = '4' THEN auxText := '4) de 50 a 69';
          WHEN i.birth_range = '5' THEN auxText := '5) de 70 o +';
        END CASE;
      ELSIF (cursorType = 'ES') THEN
        typeText := 'Education: ';
        auxText := i.education_status;
      ELSIF (cursorType = 'IR') THEN
        typeText := 'Income Range: ';
        CASE
          WHEN i.income_range = '1' THEN auxText := '1) + de 100K';
          WHEN i.income_range = '2' THEN auxText := '2) entre 70K y 100K';
          WHEN i.income_range = '3' THEN auxText := '3) entre 30K y 70K';
          WHEN i.income_range = '4' THEN auxText := '4) entre 10K y 30K';
          WHEN i.income_range = '5' THEN auxText := '5) - de 10K';
        END CASE;
      ELSE
        typeText := 'Marital Status: ';
        auxText := i.marital_status;
      END IF;

      IF (printYear) THEN
        PERFORM printData(currentYear, typeText, auxText, i.recency, i.frequency, i.monetary);
        printYear := FALSE;
      ELSE
        PERFORM printData(-1, typeText, auxText, i.recency, i.frequency, i.monetary);
      END IF;

    END LOOP;
  END
$$ LANGUAGE plpgsql;



CREATE OR REPLACE FUNCTION ReporteConsolidado(IN yearAmount INTEGER) RETURNS VOID AS $$
  DECLARE
    currentYear INT;
    maxYear INT;
    birthRangeCursor REFCURSOR;
    educationCursor REFCURSOR;
    incomeRangeCursor REFCURSOR;
    maritalStatusCursor REFCURSOR;
    totalRecency INT;
    totalFrecuency INT;
    totalMonetary INT;
  BEGIN
    IF (yearAmount <= 0) THEN
      RAISE WARNING 'La cantidad de años debe ser mayor a 0.';
      RETURN;
    END IF;

    SELECT MIN(year) INTO currentYear FROM year;
    SELECT MAX(year) INTO maxYear FROM year;

    RAISE NOTICE '--------------CONSOLIDATED CUSTOMER REPORT----------------';
    RAISE NOTICE '----------------------------------------------------------';
    RAISE NOTICE 'Year---Category-----------------Recency-Frecuency-Monetary';

    CREATE TEMP TABLE TempTable AS
        SELECT
            CASE
                WHEN getAge(Year_Birth) < 25 THEN '1'
                WHEN getAge(Year_Birth) >= 25 AND getAge(Year_Birth) < 40 THEN '2'
                WHEN getAge(Year_Birth) >= 40 AND getAge(Year_Birth) < 50 THEN '3'
                WHEN getAge(Year_Birth) >= 50 AND getAge(Year_Birth) < 70 THEN '4'
                ELSE '5'
              END AS birth_range,
              education AS education_status,
            CASE
                WHEN Income > 100000 THEN '1'
                WHEN Income BETWEEN 70001 AND 100000 THEN '2'
                WHEN Income BETWEEN 30001 AND 70000 THEN '3'
                WHEN Income BETWEEN 10000 AND 30000 THEN '4'
                ELSE '5'
              END AS income_range,
            marital_status,
            dt_customer,
            recency, NumDealsPurchases + NumWebPurchases + NumCatalogPurchases + NumStorePurchases AS frequency, MntWines + MntFruits + MntMeatProducts + MntFishProducts + MntSweetProducts AS monetary
          FROM definitiva;

    WHILE (yearAmount > 0 AND currentYear <= maxYear)
      LOOP
        RAISE NOTICE '----------------------------------------------------------';
        OPEN birthRangeCursor FOR SELECT birth_range, AVG(recency) AS recency, AVG(frequency) AS frequency, AVG(monetary) AS monetary
          FROM TempTable
          WHERE currentYear = (SELECT year FROM DAY AS d WHERE d.ID_text = Dt_Customer)
          GROUP BY birth_range
          ORDER BY birth_range;

          PERFORM readCursor(birthRangeCursor, currentYear, 'BR');
        CLOSE birthRangeCursor;

        OPEN educationCursor FOR SELECT education_status, AVG(recency) AS recency, AVG(frequency) AS frequency, AVG(monetary) AS monetary
          FROM TempTable
          WHERE currentYear = (SELECT year FROM DAY AS d WHERE d.ID_text = Dt_Customer)
          GROUP BY education_status
          ORDER BY education_status;

          PERFORM readCursor(educationCursor, currentYear, 'ES');
        CLOSE educationCursor;

        OPEN incomeRangeCursor FOR SELECT income_range, AVG(recency) AS recency, AVG(frequency) AS frequency, AVG(monetary) AS monetary
          FROM TempTable
          WHERE currentYear = (SELECT year FROM DAY AS d WHERE d.ID_text = Dt_Customer)
          GROUP BY income_range
          ORDER BY income_range;

          PERFORM readCursor(incomeRangeCursor, currentYear, 'IR');
        CLOSE incomeRangeCursor;

        OPEN maritalStatusCursor FOR SELECT marital_status, AVG(recency) AS recency, AVG(frequency) AS frequency, AVG(monetary) AS monetary
          FROM TempTable
          WHERE currentYear = (SELECT year FROM DAY AS d WHERE d.ID_text = Dt_Customer)
          GROUP BY marital_status
          ORDER BY marital_status;

          PERFORM readCursor(maritalStatusCursor, currentYear, 'MS');
        CLOSE maritalStatusCursor;

        totalRecency := (SELECT AVG(recency) FROM TempTable WHERE currentYear = (SELECT year FROM DAY AS d WHERE d.ID_text = Dt_Customer));
        totalFrecuency := (SELECT AVG(frequency) FROM TempTable WHERE currentYear = (SELECT year FROM DAY AS d WHERE d.ID_text = Dt_Customer));
        totalMonetary := (SELECT AVG(monetary) FROM TempTable WHERE currentYear = (SELECT year FROM DAY AS d WHERE d.ID_text = Dt_Customer));

        RAISE NOTICE '-----------------------------------%   %   %', totalRecency, totalFrecuency, totalMonetary;

        yearAmount := yearAmount - 1;
        currentYear := currentYear + 1;
      END LOOP;

    DROP TABLE TempTable;
    RETURN;
  END;
$$ LANGUAGE plpgsql;

SELECT ReporteConsolidado(2);

-- -- DROPS
--
-- DROP TABLE IF EXISTS definitiva;
-- DROP TABLE IF EXISTS day;
-- DROP TABLE IF EXISTS month;
-- DROP TABLE IF EXISTS quarter;
-- DROP TABLE IF EXISTS semester;
-- DROP TABLE IF EXISTS year CASCADE;
-- --------
-- DROP TRIGGER IF EXISTS beforeInsertDtCustomer ON definitiva;
