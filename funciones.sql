-- CREACION DE TABLAS

CREATE TABLE IF NOT EXISTS YEAR (
  year INT PRIMARY KEY,
  isLeap BOOLEAN NOT NULL
);

CREATE TABLE IF NOT EXISTS SEMESTER (
  semester INT CHECK(semester == 1 OR semester == 2),
  year INT,
  PRIMARY KEY (semester, year),
  FOREIGN KEY (year) REFERENCES YEAR
);

CREATE TABLE IF NOT EXISTS QUARTER (
  quarter INT CHECK(quarter BETWEEN 1 AND 4),
  semester INT,
  year INT,
  PRIMARY KEY (quarter, semester, year),
  FOREIGN KEY (semester, year) REFERENCES SEMESTER(semester, year)
);

CREATE TABLE IF NOT EXISTS MONTH (
  month INT CHECK(month BETWEEN 1 AND 12),
  quarter INT,
  year INT,
  month_name TEXT NOT NULL CHECK(month_name LIKE 'enero' OR month_name LIKE 'febrero' OR month_name LIKE 'marzo' OR month_name LIKE 'abril' OR month_name LIKE 'mayo' OR month_name LIKE 'junio' OR month_name LIKE 'julio' OR month_name LIKE 'agosto' OR month_name LIKE 'septiembre' OR month_name LIKE 'octubre' OR month_name LIKE 'noviembre' OR month_name LIKE 'diciembre'),
  PRIMARY KEY (month, quarter, year),
  FOREIGN KEY (quarter, year) REFERENCES QUARTER(quarter, year)
);

CREATE TABLE IF NOT EXISTS DAY (
  ID SERIAL
  day INT CHECK (day BETWEEN 1 AND 31),
  month INT,
  year INT,
  day_name TEXT NOT NULL CHECK(day_name LIKE 'lunes' OR day_name LIKE 'martes' OR day_name LIKE 'miercoles' OR day_name LIKE 'jueves' OR day_name LIKE 'viernes' OR day_name LIKE 'sabado' OR day_name LIKE 'domingo'),
  isWeekend BOOLEAN NOT NULL,
  PRIMARY KEY(id),
  UNIQUE (day, month, year) NOT NULL,
  FOREIGN KEY(month, year) REFERENCES MONTH(month, year)
);

CREATE TABLE IF NOT EXISTS DEFINITIVA (
  ID INT NOT NULL, 
  Year_Birth INT NOT NULL,
  Education TEXT NOT NULL,
  Marital_Status TEXT NOT NULL,
  Income INT NOT NULL,
  Kidhome INT NOT NULL,
  Teenhome INT NOT NULL,
  Dt_Customer INT NOT NULL,  --trigger to insert 
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
  FOREIGN KEY(Dt_Customer) REFERENCES DAY(ID),
  PRIMARY KEY(ID)
);

-- CODIGO TRIGGERS

CREATE TRIGGER beforeInsertDtCustomer
BEFORE INSERT ON DEFINITIVA
FOR EACH ROW
EXECUTE PROCEDURE fillTable(); -- corre un "Trigger PSM"


CREATE OR REPLACE FUNCTION fillTable() RETURNS TRIGGER AS
$$
DECLARE
  auxYear YEAR.year%TYPE;
  auxSemester SEMESTER.semester%TYPE;
  auxQuarter QUARTER.quarter%TYPE;
  auxMonth MONTH.month%TYPE;
  auxDay DAY.day%TYPE;
  auxDate DATE;
  auxStringDate TEXT;
  auxDayOfWeek INTEGER;
  isWeekend BOOLEAN;
  idDay DAY.ID%TYPE;
BEGIN
  
  auxMonth := split_part(new.Dt_Customer, '/', 1);
  auxDay := split_part(new.Dt_Customer, '/', 2);
  auxYear := split_part(new.Dt_Customer, '/', 3);

  auxStringDate := CONCAT(auxYear, auxMonth, auxDay); 
  auxDate := TO_DATE(auxStringDate, 'YYYYMMDD'); 
  
  IF (auxMonth LIKE '' OR auxDay LIKE '' OR auxYear LIKE '') THEN
    RAISE EXCEPTION 'INVALID DT_CUSTOMER';
  END IF;

  auxMonth := CAST(auxMonth AS INT);
  auxDay := CAST(auxDay AS INT);
  auxYear := CAST(auxYear AS INT);

  auxSemester := CEILING(auxMonth/6);
  auxQuarter := CEILING(auxMonth/3);

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
    INSERT INTO MONTH VALUES(auxMonth, auxQuarter, auxYear, monthName(auxMonth))
  END IF;

  IF (NOT EXISTS(SELECT day FROM DAY WHERE day = auxDay AND month = auxMonth AND year = auxYear)) THEN
    INSERT INTO DAY(day, month, year, day_name, isWeekend) VALUES(auxDay, auxMonth, auxYear, dayName(auxDayOfWeek), isWeekend)
  END IF;

  idDay := SELECT ID FROM DAY WHERE day = auxDay AND month = auxMonth AND year = auxYear;

  INSERT INTO DEFINITIVA(Year_Birth, Education, Marital_Status, Income, Kidhome, Teenhome, Dt_Customer, Recency, MntWines, MntFruits, MntMeatProducts, MntFishProducts, MntSweetProducts, NumDealsPurchases, NumWebPurchases, NumCatalogPurchases, NumStorePurchases) 
    VALUES(new.Year_Birth, new.Education, new.Marital_Status, new.Income, new.Kidhome, new.Teenhome, idDay, new.Recency, new.MntWines, new.MntFruits, new.MntMeatProducts, new.MntFishProducts, new.MntSweetProducts, new.NumDealsPurchases, new.NumWebPurchases, new.NumCatalogPurchases, new.NumStorePurchases);
  
  RETURN new;
END;
$$ LANGUAGE plpgsql;

-- CODIGO FUNCIONES

CREATE OR REPLACE FUNCTION ReporteConsolidado(IN yearAmount INTEGER);

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
    END 
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
    END 
    RETURN day_name;
  END
$$ LANGUAGE plpgsql;