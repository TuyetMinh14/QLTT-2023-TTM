---CREATE TABLE
CREATE TABLE REGIONS
(
    Regions_id     CHAR(3)     NOT NULL PRIMARY KEY,
    Region_name    VARCHAR(40) NOT NULL,
    total_projects INT
);

CREATE TABLE COUNTRIES
(
    Country_name   CHAR(48) NOT NULL PRIMARY KEY,
    Region_id      CHAR(3)  NOT NULL,
    total_projects INT,
    CONSTRAINT FK_COUNTRIES_REGIONID FOREIGN KEY (Region_id) REFERENCES REGIONS (Regions_id)
);


CREATE TABLE PROJECTS
(
    Project_id     CHAR(7)      NOT NULL PRIMARY KEY,
    Project_Name   VARCHAR(100) NOT NULL,
    Project_Status CHAR(1)      NOT NULL,
    Country        CHAR(48)     NOT NULL,
    CONSTRAINT FK_PROJECTS_COUNTRYNAME FOREIGN KEY (Country) REFERENCES COUNTRIES (Country_name)
);


CREATE TABLE TIMELINE
(
    Project_id       CHAR(7) NOT NULL PRIMARY KEY,
    Concept_Review   DATE   NOT NULL,
    Appraisal        DATE,
    Approval         DATE,
    Effective_Actual DATE,
    MidTerm_Review   DATE,
    Closing          DATE,
    Closing_Actual   DATE,
    Tot_Yrs          FLOAT,
    CONSTRAINT FK_TIMELINE_PROJECTID FOREIGN KEY (Project_id) REFERENCES PROJECTS (Project_id)
);

CREATE TABLE COST
(
    Project_id          CHAR(7) NOT NULL PRIMARY KEY,
    Estimated_Cost      FLOAT,
    Actual_Cost         FLOAT,
    Total_ICT_Component FLOAT,
    Total_WB_Disb       FLOAT,
    BB                  FLOAT,
    Avg_BBbyyr          FLOAT,
    CONSTRAINT FK_COST_PROJECTID FOREIGN KEY (Project_id) REFERENCES PROJECTS (Project_id)
);


CREATE TABLE FMIS_SOLUTION
(
    Project_id        CHAR(7) NOT NULL PRIMARY KEY,
    FMIS_Abbreviation CHAR(10),
    System_Name       CHAR(255),
    FMIS_Web_Link     CHAR(255),
    FMIS_ASW_Solution CHAR(32),
    FMIS_Since        INT,
    CONSTRAINT FK_FMIS_PROJECTID FOREIGN KEY (Project_id) REFERENCES PROJECTS (Project_id)
);

----trigger

ALTER TABLE PROJECTS
    ADD CONSTRAINT VALUE_PROJECTS_STATUS CHECK (Project_Status in ('A', 'P', 'C'));

----CHECK TIMELINE
CREATE OR REPLACE TRIGGER Check_Timeline
    BEFORE INSERT OR UPDATE
    ON TIMELINE
    REFERENCING NEW AS NEWROW
    FOR EACH ROW
BEGIN
    IF NEWROW.Concept_Review > NEWROW.Appraisal
        OR NEWROW.Concept_Review > NEWROW.Approval
        OR NEWROW.Concept_Review > NEWROW.Effective_Actual
        OR NEWROW.Concept_Review > NEWROW.MidTerm_Review
        OR NEWROW.Concept_Review > NEWROW.Closing
        OR NEWROW.Concept_Review > NEWROW.Closing_Actual
        OR NEWROW.Appraisal > NEWROW.Approval
        OR NEWROW.Appraisal > NEWROW.Effective_Actual
        OR NEWROW.Appraisal > NEWROW.MidTerm_Review
        OR NEWROW.Appraisal > NEWROW.Closing
        OR NEWROW.Appraisal > NEWROW.Closing_Actual
        OR NEWROW.Approval > NEWROW.Effective_Actual
        OR NEWROW.APPROVAL > NEWROW.MidTerm_Review
        OR NEWROW.APPROVAL > NEWROW.Closing
        OR NEWROW.APPROVAL > NEWROW.Closing_Actual
        OR NEWROW.Effective_Actual > NEWROW.MidTerm_Review
        OR NEWROW.Effective_Actual > NEWROW.Closing
        OR NEWROW.Effective_Actual > NEWROW.Closing_Actual
        OR NEWROW.MidTerm_Review > NEWROW.Closing
        OR NEWROW.MidTerm_Review > NEWROW.Closing_ACTUAL
        OR NEWROW.Closing > NEWROW.Closing_Actual
    THEN
        SIGNAL SQLSTATE '50000' SET MESSAGE_TEXT = 'TIMELINE IS NOT APPROVED';
    END IF;
END;

select *
from TIMELINE
where PROJECT_ID = 'P176765'
UPDATE TIMELINE
SET EFFECTIVE_ACTUAL = '6/25/2003'
WHERE PROJECT_ID = 'P176765';

---check trigger
SELECT *
FROM TIMELINE
WHERE PROJECT_ID = 'P000301';
UPDATE TIMELINE
SET EFFECTIVE_ACTUAL = '6/25/2020'
WHERE PROJECT_ID = 'P000301';
-------
CREATE OR REPLACE TRIGGER INSERT_TOT_YRS
AFTER UPDATE OF CLOSING_ACTUAL
ON TIMELINE
REFERENCING NEW AS NEW_ROW OLD AS OLD_ROW
FOR EACH ROW
WHEN (NEW_ROW.CLOSING_ACTUAL <> OLD_ROW.CLOSING_ACTUAL)
BEGIN
    UPDATE PROJECTS.TIMELINE T
    SET T.TOT_YRS = CAST(((DAYS(NEW_ROW.CLOSING_ACTUAL) - DAYS(NEW_ROW.CONCEPT_REVIEW)) / 360.25) AS DOUBLE)
    WHERE T.PROJECT_ID = NEW_ROW.PROJECT_ID;
END;


select *
from TIMELINE
where PROJECT_ID = 'P176765';
UPDATE TIMELINE
SET CLOSING_ACTUAL = '6/25/2030'
WHERE PROJECT_ID = 'P176765';

CREATE OR REPLACE TRIGGER UPDATE_TOT_YRS
    AFTER INSERT
    ON TIMELINE
    REFERENCING NEW AS NEW_ROW
    FOR EACH ROW
BEGIN
    DECLARE TOT DOUBLE;
    IF (NEW_ROW.CLOSING_ACTUAL IS NOT NULL) THEN
        SET TOT = CAST(((DAYS(NEW_ROW.CLOSING_ACTUAL) - DAYS(NEW_ROW.CONCEPT_REVIEW)) / 360.25) AS DOUBLE);
        INSERT INTO TIMELINE (TOT_YRS) VALUES (TOT);
    END IF;
END;
DROP TRIGGER UPDATE_TOT_YRS;


UPDATE PROJECTS.TIMELINE
SET CLOSING_ACTUAL = '03/22/200O'
WHERE PROJECT_ID = 'P000301';

SELECT CAST(((DAYS(CLOSING_ACTUAL) - DAYS(CONCEPT_REVIEW)) / 360.25) AS DOUBLE)
FROM TIMELINE
WHERE PROJECT_ID = 'P000301';



gRant update on TIMELINE TO DB2INST1;
----CAP NHAT BBPERYRS
CREATE OR REPLACE TRIGGER UPDATE_BB_PER_YRS_ON_COST
    AFTER INSERT OR UPDATE
    ON COST
    REFERENCING NEW AS NEW_ROW OLD AS OLD_ROW
    FOR EACH ROW
    WHEN (NEW_ROW.BB <> OLD_ROW.BB)
BEGIN
    IF (SELECT Tot_Yrs From TIMELINE WHERE TIMELINE.Project_id = NEW_ROW.Project_id) IS NOT NULL
    THEN
        UPDATE COST
        SET Avg_BBbyyr = NEW_ROW.BB
            / (SELECT Tot_Yrs
               FROM TIMELINE
               WHERE TIMELINE.Project_id = COST.Project_id)
        WHERE COST.Project_id = NEW_ROW.Project_id;
    END IF;
END;

CREATE OR REPLACE TRIGGER UPDATE_BB_PER_YRS_ON_TL
    AFTER UPDATE OR INSERT
    ON TIMELINE
    REFERENCING NEW AS NEW_ROW OLD AS OLD_ROW
    FOR EACH ROW
    WHEN (NEW_ROW.TOT_YRS <> OLD_ROW.TOT_YRS)
BEGIN
    DECLARE v_BB DECIMAL(10, 2);

    IF (SELECT Tot_Yrs FROM TIMELINE WHERE Project_id = NEW_ROW.Project_id) IS NOT NULL
    THEN
        SELECT BB INTO v_BB FROM COST WHERE Project_id = NEW_ROW.Project_id;

        IF NEW_ROW.Tot_Yrs <> 0
        THEN
            UPDATE COST
            SET Avg_BBbyyr = v_BB / NEW_ROW.Tot_Yrs
            WHERE Project_id = NEW_ROW.Project_id;
        END IF;
    END IF;
END;

select *
from COST
where PROJECT_ID = 'P176765';
UPDATE COST SET BB = '800000' WHERE PROJECT_ID = 'P176765';
----TOTAL_PROJECTS------->PASS
CREATE OR REPLACE TRIGGER TOTAL_PROJECTS
    AFTER INSERT
    ON PROJECTS
    REFERENCING NEW AS NEW_ROW
    FOR EACH ROW
BEGIN
    UPDATE COUNTRIES
    SET total_projects = (SELECT COUNT(*)
                          FROM PROJECTS
                          WHERE COUNTRIES.Country_name = PROJECTS.Country
                          group by Country)
    WHERE COUNTRIES.Country_name = NEW_ROW.Country;
END;

--------
CREATE OR REPLACE TRIGGER UPDATE_TOTALPROJECTS
    AFTER UPDATE OF COUNTRY
    ON PROJECTS
    REFERENCING NEW AS NEW_ROW OLD AS OLD_ROW
    FOR EACH ROW
    WHEN (NEW_ROW.COUNTRY <> OLD_ROW.COUNTRY)
BEGIN
    UPDATE COUNTRIES
    SET total_projects = total_projects - 1
    WHERE Country_name = OLD_ROW.Country;

    UPDATE COUNTRIES
    SET total_projects = total_projects + 1
    WHERE Country_name = NEW_ROW.Country;
END;


CREATE OR REPLACE TRIGGER UPDATE_REGIONS_TL
    AFTER UPDATE
    ON COUNTRIES
    REFERENCING NEW AS NEW_ROW
    FOR EACH ROW
BEGIN
    -- Update the total_projects column in REGIONS table
    UPDATE REGIONS
    SET total_projects = (SELECT SUM(total_projects)
                          FROM COUNTRIES
                          WHERE Region_id = NEW_ROW.Region_id
                          GROUP BY REGION_ID)
    WHERE REGIONS.Regions_id = NEW_ROW.Region_id;
END;

SELECT * FROM COUNTRIES WHERE COUNTRY_NAME = 'Argentina';
SELECT * FROM PROJECTS WHERE COUNTRY = 'Burkina Faso';
SELECT * FROM PROJECTS WHERE PROJECT_ID = 'P000301';
SELECT * FROM REGIONS WHERE REGIONS_ID = 'AFR';
SELECT * FROM REGIONS WHERE REGIONS_ID = 'LCR';
UPDATE PROJECTS
SET COUNTRY = 'Argentina'
WHERE PROJECT_ID = 'P000301';
----PROC ADD PROJECT
CREATE OR REPLACE PROCEDURE ADD_PROJECT(IN @PROJECT_NAME CHAR(48), IN @COUNTRY CHAR(48), IN @PROJECT_STATUS CHAR(1))
    LANGUAGE SQL
BEGIN
    DECLARE new_project_id CHAR(7);
    DECLARE is_duplicate INT;

    -- Tạo mã project duy nhất
    SET new_project_id =
            (SELECT CONCAT('P', RIGHT('0000000' || CAST(CAST(MAX(SUBSTR(Project_id, 2)) AS INT) + 1 AS CHAR(7)), 7))
             FROM PROJECTS);

    -- Kiểm tra xem mã project đã tồn tại hay chưa
    SET is_duplicate = (SELECT COUNT(*) FROM PROJECTS WHERE Project_id = new_project_id);

    -- Nếu mã project đã tồn tại, tăng mã lên cho đến khi tìm được mã không trùng
    WHILE is_duplicate > 0
        DO
            SET new_project_id = (SELECT CONCAT('P', RIGHT(
                        '0000000' || CAST(CAST(SUBSTR(new_project_id, 2) AS INT) + 1 AS CHAR(7)), 7))
                                  FROM PROJECTS);
            SET is_duplicate = (SELECT COUNT(*) FROM PROJECTS WHERE Project_id = new_project_id);
        END WHILE;

    -- Thêm project mới vào bảng PROJECTS
    INSERT INTO PROJECTS (Project_id, Project_name, COUNTRY, PROJECT_STATUS)
    VALUES (new_project_id, @PROJECT_NAME, @COUNTRY, @PROJECT_STATUS);
    INSERT INTO COST (Project_id)
    VALUES (new_project_id);
    INSERT INTO FMIS_SOLUTION (Project_id)
    VALUES (new_project_id);
    INSERT INTO TIMELINE (Project_id, CONCEPT_REVIEW)
    VALUES (new_project_id, CURRENT_DATE);
END;



BEGIN
    CALL PROJECTS.ADD_PROJECT('PUBLIC FINANCIAL', 'Viet Nam', 'P');
END;


----INSERT DATA

---REGIONS
INSERT INTO REGIONS
VALUES ('AFR', 'Africa', NULL);
INSERT INTO REGIONS
VALUES ('EAP', 'East Asia and Pacific', NULL);
INSERT INTO REGIONS
VALUES ('ECA', 'Europe and Central Asia', NULL);
INSERT INTO REGIONS
VALUES ('LCR', 'Latin America and Caribbean', NULL);
INSERT INTO REGIONS
VALUES ('MND', 'Middle East and North Africa', NULL);
INSERT INTO REGIONS
VALUES ('SAR', 'South Asia', NULL);


--COUNTRIES
INSERT INTO COUNTRIES
VALUES ('Afghanistan', 'SAR', NULL);
INSERT INTO COUNTRIES
VALUES ('Albania', 'ECA', NULL);
INSERT INTO COUNTRIES
VALUES ('Algeria', 'MND', NULL);
INSERT INTO COUNTRIES
VALUES ('Argentina', 'LCR', NULL);
INSERT INTO COUNTRIES
VALUES ('Armenia', 'ECA', NULL);
INSERT INTO COUNTRIES
VALUES ('Azerbaijan', 'ECA', NULL);
INSERT INTO COUNTRIES
VALUES ('Bangladesh', 'SAR', NULL);
INSERT INTO COUNTRIES
VALUES ('Belarus', 'ECA', NULL);
INSERT INTO COUNTRIES
VALUES ('Bolivia', 'LCR', NULL);
INSERT INTO COUNTRIES
VALUES ('Brazil', 'LCR', NULL);
INSERT INTO COUNTRIES
VALUES ('Burkina Faso', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Burundi', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Cabo Verde', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Cambodia', 'EAP', NULL);
INSERT INTO COUNTRIES
VALUES ('Cameroon', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Central African Republic', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Chad', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Chile', 'LCR', NULL);
INSERT INTO COUNTRIES
VALUES ('China', 'EAP', NULL);
INSERT INTO COUNTRIES
VALUES ('Colombia', 'LCR', NULL);
INSERT INTO COUNTRIES
VALUES ('Comoros', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Congo, Democratic Republic of', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Costa Rica', 'LCR', NULL);
INSERT INTO COUNTRIES
VALUES ('Cote dIvoire', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Ecuador', 'LCR', NULL);
INSERT INTO COUNTRIES
VALUES ('El Salvador', 'LCR', NULL);
INSERT INTO COUNTRIES
VALUES ('Eswatini', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Ethiopia', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Gambia, The', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Georgia', 'ECA', NULL);
INSERT INTO COUNTRIES
VALUES ('Ghana', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Guatemala', 'LCR', NULL);
INSERT INTO COUNTRIES
VALUES ('Guinea-Bissau', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Haiti', 'LCR', NULL);
INSERT INTO COUNTRIES
VALUES ('Honduras', 'LCR', NULL);
INSERT INTO COUNTRIES
VALUES ('Hungary', 'ECA', NULL);
INSERT INTO COUNTRIES
VALUES ('India', 'SAR', NULL);
INSERT INTO COUNTRIES
VALUES ('Indonesia', 'EAP', NULL);
INSERT INTO COUNTRIES
VALUES ('Iraq', 'MND', NULL);
INSERT INTO COUNTRIES
VALUES ('Jamaica', 'LCR', NULL);
INSERT INTO COUNTRIES
VALUES ('Kazakhstan', 'ECA', NULL);
INSERT INTO COUNTRIES
VALUES ('Kenya', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Kosovo', 'ECA', NULL);
INSERT INTO COUNTRIES
VALUES ('Kyrgyz Republic', 'ECA', NULL);
INSERT INTO COUNTRIES
VALUES ('Lao Peoples Democratic Republic', 'EAP', NULL);
INSERT INTO COUNTRIES
VALUES ('Lesotho', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Liberia', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Madagascar', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Malawi', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Maldives', 'SAR', NULL);
INSERT INTO COUNTRIES
VALUES ('Marshall Islands', 'EAP', NULL);
INSERT INTO COUNTRIES
VALUES ('Mauritania', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Mexico', 'LCR', NULL);
INSERT INTO COUNTRIES
VALUES ('Micronesia, Fed. Sts.', 'EAP', NULL);
INSERT INTO COUNTRIES
VALUES ('Moldova', 'ECA', NULL);
INSERT INTO COUNTRIES
VALUES ('Mongolia', 'EAP', NULL);
INSERT INTO COUNTRIES
VALUES ('Myanmar', 'EAP', NULL);
INSERT INTO COUNTRIES
VALUES ('Nepal', 'SAR', NULL);
INSERT INTO COUNTRIES
VALUES ('Nicaragua', 'LCR', NULL);
INSERT INTO COUNTRIES
VALUES ('Niger', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Nigeria', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('North Macedonia', 'ECA', NULL);
INSERT INTO COUNTRIES
VALUES ('OECS countries', 'LCR', NULL);
INSERT INTO COUNTRIES
VALUES ('Pakistan', 'SAR', NULL);
INSERT INTO COUNTRIES
VALUES ('Panama', 'LCR', NULL);
INSERT INTO COUNTRIES
VALUES ('Russian Federation', 'ECA', NULL);
INSERT INTO COUNTRIES
VALUES ('Rwanda', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Senegal', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Sierra Leone', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Slovak Republic', 'ECA', NULL);
INSERT INTO COUNTRIES
VALUES ('Somalia', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('South Sudan', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Tajikistan', 'ECA', NULL);
INSERT INTO COUNTRIES
VALUES ('Tanzania', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Timor-Leste', 'EAP', NULL);
INSERT INTO COUNTRIES
VALUES ('Türkiye', 'ECA', NULL);
INSERT INTO COUNTRIES
VALUES ('Uganda', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Ukraine', 'ECA', NULL);
INSERT INTO COUNTRIES
VALUES ('Venezuela, Republica Bolivariana de', 'LCR', NULL);
INSERT INTO COUNTRIES
VALUES ('Viet Nam', 'EAP', NULL);
INSERT INTO COUNTRIES
VALUES ('West Bank and Gaza/Palestine', 'MND', NULL);
INSERT INTO COUNTRIES
VALUES ('Yemen, Republic of', 'MND', NULL);
INSERT INTO COUNTRIES
VALUES ('Zambia', 'AFR', NULL);
INSERT INTO COUNTRIES
VALUES ('Zimbabwe', 'AFR', NULL);

---PROJECTS
INSERT INTO PROJECTS
VALUES ('P000301', 'Public Institutional Development Project', 'C', 'Burkina Faso');
INSERT INTO PROJECTS
VALUES ('P155121', 'Burkina Faso Economic Governance, GovTech and Citizen Engage', 'C', 'Burkina Faso');
INSERT INTO PROJECTS
VALUES ('P078627', 'Economic Management Support Project', 'C', 'Burundi');
INSERT INTO PROJECTS
VALUES ('P084160', 'Transparency and Accountability Capacity Building Project', 'C', 'Cameroon');
INSERT INTO PROJECTS
VALUES ('P057998', 'Public Sector Reform And Capacity Building Project (02);', 'C', 'Cabo Verde');
INSERT INTO PROJECTS
VALUES ('P161730', 'Public Expenditure and Investment Management Reform Project', 'C', 'Central African Republic');
INSERT INTO PROJECTS
VALUES ('P090265', 'Public Financial Management Capacity Building', 'C', 'Chad');
INSERT INTO PROJECTS
VALUES ('P102376', 'Economic Governance Technical Assistance Project', 'C', 'Comoros');
INSERT INTO PROJECTS
VALUES ('P104041', 'Enhancing Governance Capacity', 'C', 'Congo, Democratic Republic of');
INSERT INTO PROJECTS
VALUES ('P145747', 'DRC: Strengthening PFM and Accountability', 'C', 'Congo, Democratic Republic of');
INSERT INTO PROJECTS
VALUES ('P107355', 'CI-Governance and Institutional Dev.', 'C', 'Cote dIvoire');
INSERT INTO PROJECTS
VALUES ('P150922', 'PFM Project', 'C', 'Ethiopia');
INSERT INTO PROJECTS
VALUES ('P057995', 'Capacity Building for Economic Management Prj', 'C', 'Gambia, The');
INSERT INTO PROJECTS
VALUES ('P117275', 'GM-Integrated Financial Management and Information System Project-Additional Financing', 'C',
        'Gambia, The');
INSERT INTO PROJECTS
VALUES ('P045588', 'Public Financial Management Technical Assistance Project', 'C', 'Ghana');
INSERT INTO PROJECTS
VALUES ('P093610', 'e-Ghana (Additional Financing);', 'C', 'Ghana');
INSERT INTO PROJECTS
VALUES ('P151447', 'GH-PFM Reform and Improvement', 'C', 'Ghana');
INSERT INTO PROJECTS
VALUES ('P150827', 'Public Sector Strengthening Project ', 'C', 'Guinea-Bissau');
INSERT INTO PROJECTS
VALUES ('P066490', 'Public Sector Management Technical Assistance Project', 'C', 'Kenya');
INSERT INTO PROJECTS
VALUES ('P090567', 'Institutional Reform and Capacity Building Technical Assistance Project', 'C', 'Kenya');
INSERT INTO PROJECTS
VALUES ('P143197', 'LS-PFM Reform Support Program', 'C', 'Lesotho');
INSERT INTO PROJECTS
VALUES ('P109775', 'Public Financial Management - IFMIS', 'C', 'Liberia');
INSERT INTO PROJECTS
VALUES ('P127319', 'Liberia Integrated Public Financial Management Reform Project', 'C', 'Liberia');
INSERT INTO PROJECTS
VALUES ('P074448', 'Governance and Institutional Development Project', 'C', 'Madagascar');
INSERT INTO PROJECTS
VALUES ('P103950', 'Governance and Institutional Development Project II', 'C', 'Madagascar');
INSERT INTO PROJECTS
VALUES ('P001657', 'Institutional Development Project (2);', 'C', 'Malawi');
INSERT INTO PROJECTS
VALUES ('P078408', 'Financial Mgmt, Transparency and Accountability Prj (FIMTAP);', 'C', 'Malawi');
INSERT INTO PROJECTS
VALUES ('P130878', 'Financial Reporting and Oversight Improvement Project', 'C', 'Malawi');
INSERT INTO PROJECTS
VALUES ('P146804', 'Governance Enhancement Project', 'C', 'Mauritania');
INSERT INTO PROJECTS
VALUES ('P108253', 'Niger Reform Management and TA', 'C', 'Niger');
INSERT INTO PROJECTS
VALUES ('P065301', 'Economic Management Capacity Building Prj', 'C', 'Nigeria');
INSERT INTO PROJECTS
VALUES ('P074447', 'State Governance and Capacity Building Project', 'C', 'Nigeria');
INSERT INTO PROJECTS
VALUES ('P088150', 'Federal Government Economic Reform and Governance Project', 'C', 'Nigeria');
INSERT INTO PROJECTS
VALUES ('P097026', 'Nigeria Public Sector Governance Reform and Development Project', 'C', 'Nigeria');
INSERT INTO PROJECTS
VALUES ('P121455', 'State Employment and Expenditure for Results Project', 'C', 'Nigeria');
INSERT INTO PROJECTS
VALUES ('P133045', 'State and Local Governance Reform Project', 'C', 'Nigeria');
INSERT INTO PROJECTS
VALUES ('P066386', 'RW-PUBLIC SECTOR CAPACITY BUILDING PROJECT', 'C', 'Rwanda');
INSERT INTO PROJECTS
VALUES ('P149095', 'Public Sector Governance Program For Results', 'C', 'Rwanda');
INSERT INTO PROJECTS
VALUES ('P122476', 'Public Financial Management Strengthening Technical Assistance Project', 'C', 'Senegal');
INSERT INTO PROJECTS
VALUES ('P078613', 'Institutional Reform & Capacity Building', 'C', 'Sierra Leone');
INSERT INTO PROJECTS
VALUES ('P108069', 'Public Financial Management', 'C', 'Sierra Leone');
INSERT INTO PROJECTS
VALUES ('P133424', 'Public Financial Management Improvement and Consolidation Project', 'C', 'Sierra Leone');
INSERT INTO PROJECTS
VALUES ('P146006', 'Somalia PFM Capacity Strengthening Project', 'C', 'Somalia');
INSERT INTO PROJECTS
VALUES ('P070544', 'Accountability, Transparency & Integrity Program', 'C', 'Tanzania');
INSERT INTO PROJECTS
VALUES ('P002975', 'Economic and Financial Management Project', 'C', 'Uganda');
INSERT INTO PROJECTS
VALUES ('P044679', 'Second Economic and Financial Management Project', 'C', 'Uganda');
INSERT INTO PROJECTS
VALUES ('P050400', 'Public Service Capacity Building Project', 'C', 'Zambia');
INSERT INTO PROJECTS
VALUES ('P082452', 'Public Sector Management Program Support Project', 'C', 'Zambia');
INSERT INTO PROJECTS
VALUES ('P147343', 'Public Financial Management Reform Program Phase I', 'C', 'Zambia');
INSERT INTO PROJECTS
VALUES ('P152932', 'Public Financial Mgmt Enhancement Project ', 'C', 'Zimbabwe');
INSERT INTO PROJECTS
VALUES ('P087945', 'Public Financial Management and Accountability', 'C', 'Cambodia');
INSERT INTO PROJECTS
VALUES ('P143774', 'Cambodia PFM Modernization Project', 'C', 'Cambodia');
INSERT INTO PROJECTS
VALUES ('P036041', 'Fiscal Technical Assistance Project', 'C', 'China');
INSERT INTO PROJECTS
VALUES ('P004019', 'Accountancy Development Project (2);', 'C', 'Indonesia');
INSERT INTO PROJECTS
VALUES ('P085133', 'Government Financial Management and Revenue Administration Project', 'C', 'Indonesia');
INSERT INTO PROJECTS
VALUES ('P077620', 'Financial Management Capacity Building Credit', 'C', 'Lao Peoples Democratic Republic');
INSERT INTO PROJECTS
VALUES ('P051855', 'Fiscal Accounting Technical Assistance (c 3081);', 'C', 'Mongolia');
INSERT INTO PROJECTS
VALUES ('P077778', 'Economic Capacity Building TA (ECTAP);', 'C', 'Mongolia');
INSERT INTO PROJECTS
VALUES ('P144952', 'Myanmar Public Finance Management Modernization Project', 'C', 'Myanmar');
INSERT INTO PROJECTS
VALUES ('P092484', 'Planning and Financial Management Capacity Building Program', 'C', 'Timor-Leste');
INSERT INTO PROJECTS
VALUES ('P075399', 'Public Financial Management Reform Project', 'C', 'Vietnam');
INSERT INTO PROJECTS
VALUES ('P069939', 'Public Administration Reform Project', 'C', 'Albania');
INSERT INTO PROJECTS
VALUES ('P105143', 'MDTF for Capacity Building & Support to Implement the Integrated Planning System', 'C', 'Albania');
INSERT INTO PROJECTS
VALUES ('P129332', 'Second MDTF for Capacity Building Support to Implement the IPS (IPS 2);', 'C', 'Albania');
INSERT INTO PROJECTS
VALUES ('P149913', 'Public Sector Modernization Project III', 'C', 'Armenia');
INSERT INTO PROJECTS
VALUES ('P066100', '(former IBTA-II); Highly Pathogenic Avian Influenza Preparedness Project', 'C', 'Azerbaijan');
INSERT INTO PROJECTS
VALUES ('P146997', 'PFM Modernization Project', 'C', 'Belarus');
INSERT INTO PROJECTS
VALUES ('P063081', 'Public Sector Financial Management Reform Support', 'C', 'Georgia');
INSERT INTO PROJECTS
VALUES ('P043446', 'Public Finance Management Project', 'C', 'Hungary');
INSERT INTO PROJECTS
VALUES ('P037960', 'Treasury Modernization Project', 'C', 'Kazakhstan');
INSERT INTO PROJECTS
VALUES ('P101614', 'Public Sector Modernization Project', 'C', 'Kosovo');
INSERT INTO PROJECTS
VALUES ('P071063', 'Governance Technical Assistance Project', 'C', 'Kyrgyz Republic');
INSERT INTO PROJECTS
VALUES ('P082916', 'Public Financial Management Technical Assistance Project', 'C', 'Moldova');
INSERT INTO PROJECTS
VALUES ('P064508', 'Treasury Development Project', 'C', 'Russian Federation');
INSERT INTO PROJECTS
VALUES ('P122998', 'Fiscal and Financial Development', 'C', 'Russian Federation');
INSERT INTO PROJECTS
VALUES ('P069864', 'Public Finance Management Project', 'C', 'Slovak Republic');
INSERT INTO PROJECTS
VALUES ('P099840', 'Public Financial Management Modernization', 'C', 'Tajikistan');
INSERT INTO PROJECTS
VALUES ('P035759', 'Public Finance Management Project', 'C', 'Türkiye');
INSERT INTO PROJECTS
VALUES ('P049174', 'Treasury Systems Project', 'C', 'Ukraine');
INSERT INTO PROJECTS
VALUES ('P090389', 'Public Finance Modernization Project', 'C', 'Ukraine');
INSERT INTO PROJECTS
VALUES ('P006029', 'Public Sector Reform Technical Assistance Project', 'C', 'Argentina');
INSERT INTO PROJECTS
VALUES ('P037049', 'Public Investment Strengthening Technical Assistance Project', 'C', 'Argentina');
INSERT INTO PROJECTS
VALUES ('P006160', 'Public Financial Management Project', 'C', 'Bolivia');
INSERT INTO PROJECTS
VALUES ('P006189', 'Public Financial Management (2); Project', 'C', 'Bolivia');
INSERT INTO PROJECTS
VALUES ('P040110', 'Financial Decentralization & Accountability Prj', 'C', 'Bolivia');
INSERT INTO PROJECTS
VALUES ('P006394', 'Public Sector Management Loan Project', 'C', 'Brazil');
INSERT INTO PROJECTS
VALUES ('P073294', 'Fiscal and Financial Management Technical Assistance Loan', 'C', 'Brazil');
INSERT INTO PROJECTS
VALUES ('P006669', 'Public Sector Management Project (2);', 'C', 'Chile');
INSERT INTO PROJECTS
VALUES ('P069259', 'Public Expenditure Management Project', 'C', 'Chile');
INSERT INTO PROJECTS
VALUES ('P103441', 'Second Public Expenditure Management', 'C', 'Chile');
INSERT INTO PROJECTS
VALUES ('P006889', 'Public Financial Management Project', 'C', 'Colombia');
INSERT INTO PROJECTS
VALUES ('P040109', 'Public Financial Management Project (02);', 'C', 'Colombia');
INSERT INTO PROJECTS
VALUES ('P106628', 'Improving Public Management Project', 'C', 'Colombia');
INSERT INTO PROJECTS
VALUES ('P007071', 'Public Sector Management Project', 'C', 'Ecuador');
INSERT INTO PROJECTS
VALUES ('P007136', 'Modernization of the State Technical Assistance Project', 'C', 'Ecuador');
INSERT INTO PROJECTS
VALUES ('P074218', 'Public Sector Financial Management Project', 'C', 'Ecuador');
INSERT INTO PROJECTS
VALUES ('P007164', 'Public Sector Modernization Technical Assistance Project', 'C', 'El Salvador');
INSERT INTO PROJECTS
VALUES ('P095314', 'Fiscal Management and Public Sector Performance TA Loan', 'C', 'El Salvador');
INSERT INTO PROJECTS
VALUES ('P007213', 'Integrated Financial Management Project', 'C', 'Guatemala');
INSERT INTO PROJECTS
VALUES ('P048657', 'Integrated Financial Management II', 'C', 'Guatemala');
INSERT INTO PROJECTS
VALUES ('P066175', 'Integrated Financial Management III - TA Prj', 'C', 'Guatemala');
INSERT INTO PROJECTS
VALUES ('P034607', 'Public Sector Modernization Technical Assistance Credit', 'C', 'Honduras');
INSERT INTO PROJECTS
VALUES ('P060785', 'Economic and Financial Management Project', 'C', 'Honduras');
INSERT INTO PROJECTS
VALUES ('P110050', 'Improving Public Sector Performance ', 'C', 'Honduras');
INSERT INTO PROJECTS
VALUES ('P007457', 'Financial and Program Management Improvement Project', 'C', 'Jamaica');
INSERT INTO PROJECTS
VALUES ('P007490', 'Public Sector Modernization Project', 'C', 'Jamaica');
INSERT INTO PROJECTS
VALUES ('P035080', 'Institutional Development Credit (IDC); Project', 'C', 'Nicaragua');
INSERT INTO PROJECTS
VALUES ('P049296', 'Economic Management Technical Assistance', 'C', 'Nicaragua');
INSERT INTO PROJECTS
VALUES ('P078891', 'Public Sector Technical Assistance Project', 'C', 'Nicaragua');
INSERT INTO PROJECTS
VALUES ('P111795', 'Public Financial Management Modernization Project', 'C', 'Nicaragua');
INSERT INTO PROJECTS
VALUES ('P121492', 'Enhanced Public Sector Efficiency Technical Assistance Loan', 'C', 'Panama');
INSERT INTO PROJECTS
VALUES ('P100635', 'OECS E-Government for Regional Integration Program (APL);', 'C', 'OECS Countries');
INSERT INTO PROJECTS
VALUES ('P057601', 'Public Expenditure Management Reform Project', 'C', 'Venezuela, Republica Bolivariana de');
INSERT INTO PROJECTS
VALUES ('P064921', 'Budget System Modernization', 'C', 'Algeria');
INSERT INTO PROJECTS
VALUES ('P050706', 'Civil Service Modernization Project', 'C', 'Yemen, Republic of');
INSERT INTO PROJECTS
VALUES ('P117363', 'Public Finance Modernization Project', 'C', 'Yemen, Republic of');
INSERT INTO PROJECTS
VALUES ('P077417', 'Emergency Public Administration Project', 'C', 'Afghanistan');
INSERT INTO PROJECTS
VALUES ('P082610', 'Emergency Public Administration Project II', 'C', 'Afghanistan');
INSERT INTO PROJECTS
VALUES ('P084736', 'Public Admin Cpacity Building Project', 'C', 'Afghanistan');
INSERT INTO PROJECTS
VALUES ('P099980', 'Public Financial Management Reform Project', 'C', 'Afghanistan');
INSERT INTO PROJECTS
VALUES ('P120427', 'Public Financial Management Reform II', 'C', 'Afghanistan');
INSERT INTO PROJECTS
VALUES ('P159655', 'Public Financial Management (PFM); for improved service deliv', 'C', 'Afghanistan');
INSERT INTO PROJECTS
VALUES ('P117248', 'Deepening MTBF and Strengthening Financial Accountability', 'C', 'Bangladesh');
INSERT INTO PROJECTS
VALUES ('P094193', 'Post Tsunami Emergency Relief and Reconstruction Project', 'C', 'Maldives');
INSERT INTO PROJECTS
VALUES ('P145317', 'Maldives: PFM Systems Strengthening Project', 'C', 'Maldives');
INSERT INTO PROJECTS
VALUES ('P125770', 'Strengthening PFM Systems in Nepal', 'C', 'Nepal');
INSERT INTO PROJECTS
VALUES ('P036015', 'Improvement to Financial Reporting and Auditing Project', 'C', 'Pakistan');
INSERT INTO PROJECTS
VALUES ('P076872', 'Second Improvement to Financial Reporting and Auditing Project', 'C', 'Pakistan');
INSERT INTO PROJECTS
VALUES ('P174620', 'CAR- Public Sector Digital Governance Project', 'A', 'Central African Republic');
INSERT INTO PROJECTS
VALUES ('P165000', 'Integrated Public Financial Management Reform Project II', 'A', 'Liberia');
INSERT INTO PROJECTS
VALUES ('P174822', 'Niger - Public Finance Management Reform for Resilience and Service Delivery', 'A', 'Niger');
INSERT INTO PROJECTS
VALUES ('P163540', 'Fiscal Governance and Institutions Project', 'A', 'Nigeria');
INSERT INTO PROJECTS
VALUES ('P164807', 'Rwanda Public Finance Management Reform Project', 'A', 'Rwanda');
INSERT INTO PROJECTS
VALUES ('P151492', 'Somalia: Public Financial Management Capacity Strengthening Project II', 'A', 'Somalia');
INSERT INTO PROJECTS
VALUES ('P176761', 'South Sudan Public Financial Management and Institutional St', 'A', 'South Sudan');
INSERT INTO PROJECTS
VALUES ('P167534', 'Lao PDR Public Finance Management Modernization Project', 'A', 'Lao Peoples Democratic Republic');
INSERT INTO PROJECTS
VALUES ('P163131', 'Strengthening budget execution and financial reporting systems in the Republic of Marshall Islands',
        'A', 'Marshall Islands');
INSERT INTO PROJECTS
VALUES ('P161969',
        'Strengthening budget execution and financial reporting systems in the Federated States of Micronesia ', 'A',
        'Micronesia, Fed. Sts.');
INSERT INTO PROJECTS
VALUES ('P176366', 'Building Effective, Transparent and Accountable Public Finan', 'A', 'North Macedonia');
INSERT INTO PROJECTS
VALUES ('P150381', 'Public Finance Management Modernization', 'A', 'Tajikistan');
INSERT INTO PROJECTS
VALUES ('P172352', 'Costa Rica Fiscal Management Improvement Project', 'A', 'Costa Rica');
INSERT INTO PROJECTS
VALUES ('P157531', 'Improving Haitis Public Financial Management and Statistical Information Project', 'A', 'Haiti');
INSERT INTO PROJECTS
VALUES ('P169959', 'Modernization of Public Financial Management Systems in Mexico', 'A', 'Mexico');
INSERT INTO PROJECTS
VALUES ('P151357', 'PFM Institutional Development and Capacity Building', 'A', 'Iraq');
INSERT INTO PROJECTS
VALUES ('P162850', 'Public Financial Management Modernization and Accountability', 'A', 'West Bank and Gaza/Palestine');
INSERT INTO PROJECTS
VALUES ('P167491', 'Bangladesh Strengthening PFM Program for Enhanced Service De', 'A', 'Bangladesh');
INSERT INTO PROJECTS
VALUES ('P156687', 'Himachal Pradesh Public Financial Management Capacity Building Project', 'A', 'India');
INSERT INTO PROJECTS
VALUES ('P156869', 'Strengthening Public Financial Management in Rajasthan', 'A', 'India');
INSERT INTO PROJECTS
VALUES ('P157198', 'Assam State Public Finance Institutional Reforms (ASPIRe); Project', 'A', 'India');
INSERT INTO PROJECTS
VALUES ('P166578', 'Chhattisgarh Public Financial Management and Accountability', 'A', 'India');
INSERT INTO PROJECTS
VALUES ('P166923', 'Uttarakhand Public Financial Management Strengthening Progra', 'A', 'India');
INSERT INTO PROJECTS
VALUES ('P164783', 'Integrated Public Financial Management Reform Project', 'A', 'Nepal');


---TIME LINE
INSERT INTO TIMELINE
VALUES ('P000301', '07/15/1991', '11/04/1991', '06/04/1992', '03/22/1993', '06/15/1996', '03/22/1997', '12/31/2000',
        NULL);
INSERT INTO TIMELINE
VALUES ('P155121', '06/04/2015', '11/09/2015', '02/18/2016', '10/14/2016', '06/03/2020', '12/31/2021', '06/30/2022',
        NULL);
INSERT INTO TIMELINE
VALUES ('P078627', '01/16/2003', '08/08/2003', '01/29/2004', '04/29/2004', NULL, '07/31/2009', '07/31/2012', NULL);
INSERT INTO TIMELINE
VALUES ('P084160', '03/31/2004', '03/18/2008', '06/24/2008', '06/05/2009', '07/25/2011', '12/31/2012', '12/31/2012',
        NULL);
INSERT INTO TIMELINE
VALUES ('P057998', '03/24/1999', '05/08/1999', '11/23/1999', '06/15/2000', '10/15/2001', '12/31/2001', '12/31/2002',
        NULL);
INSERT INTO TIMELINE
VALUES ('P161730', '03/09/2017', '05/03/2017', '06/19/2017', '11/15/2017', '03/16/2020', '06/30/2021', '12/31/2021',
        NULL);
INSERT INTO TIMELINE
VALUES ('P090265', '10/06/2004', '02/12/2007', '05/24/2007', '04/22/2009', '06/10/2011', '12/31/2012', '12/31/2016',
        NULL);
INSERT INTO TIMELINE
VALUES ('P102376', '09/29/2006', '11/22/2010', '01/31/2011', '02/28/2011', '03/26/2012', '12/31/2013', '12/31/2016',
        NULL);
INSERT INTO TIMELINE
VALUES ('P104041', '05/30/2007', '01/07/2008', '04/22/2008', '08/23/2008', '11/16/2010', '02/28/2013', '02/28/2016',
        NULL);
INSERT INTO TIMELINE
VALUES ('P145747', '02/26/2013', '10/07/2013', '01/30/2014', '05/23/2014', '03/29/2018', '12/31/2018', '12/31/2021',
        NULL);
INSERT INTO TIMELINE
VALUES ('P107355', '05/13/2008', '05/19/2008', '06/12/2008', '10/22/2008', '10/05/2010', '12/15/2012', '11/30/2016',
        NULL);
INSERT INTO TIMELINE
VALUES ('P150922', '07/03/2014', '02/23/2015', '02/26/2016', '05/18/2016', '04/11/2018', '04/07/2020', '03/07/2022',
        NULL);
INSERT INTO TIMELINE
VALUES ('P057995', '03/10/1999', '04/09/2001', '07/26/2001', '01/03/2002', '06/30/2004', '12/31/2006', '12/31/2008',
        NULL);
INSERT INTO TIMELINE
VALUES ('P117275', '07/30/2009', '04/21/2010', '06/01/2010', '08/10/2010', '10/15/2012', '12/31/2012', '11/30/2020',
        NULL);
INSERT INTO TIMELINE
VALUES ('P045588', '11/03/1995', '06/25/1996', '11/07/1996', '04/04/1997', '07/24/1999', '06/30/2001', '07/31/2003',
        NULL);
INSERT INTO TIMELINE
VALUES ('P093610', '02/18/2010', '05/04/2010', '06/23/2010', '07/30/2010', '12/01/2010', '12/31/2012', '12/30/2014',
        NULL);
INSERT INTO TIMELINE
VALUES ('P151447', '01/27/2015', '03/24/2015', '05/15/2015', '08/18/2015', '11/22/2017', '06/30/2019', '12/31/2021',
        NULL);
INSERT INTO TIMELINE
VALUES ('P150827', '10/07/2014', '01/23/2015', '03/24/2015', '06/22/2015', '07/14/2017', '12/31/2018', '11/30/2020',
        NULL);
INSERT INTO TIMELINE
VALUES ('P066490', '06/12/2000', '11/27/2000', '07/31/2001', '11/12/2001', '06/27/2003', '12/31/2004', '06/30/2005',
        NULL);
INSERT INTO TIMELINE
VALUES ('P090567', '11/30/2004', '10/03/2005', '01/24/2006', '07/19/2006', '09/21/2009', '11/30/2010', '08/31/2011',
        NULL);
INSERT INTO TIMELINE
VALUES ('P143197', '01/29/2013', '12/02/2013', '02/06/2014', '07/25/2014', '04/08/2016', '07/03/2017', '07/03/2019',
        NULL);
INSERT INTO TIMELINE
VALUES ('P109775', '12/18/2008', '12/18/2008', '02/02/2009', '03/20/2009', '04/14/2011', '02/01/2012', '02/01/2012',
        NULL);
INSERT INTO TIMELINE
VALUES ('P127319', '08/04/2011', '10/31/2011', '12/15/2011', '09/18/2012', '06/06/2016', '06/30/2016', '06/30/2017',
        NULL);
INSERT INTO TIMELINE
VALUES ('P074448', '09/27/2001', '08/19/2003', '11/18/2003', '03/03/2004', '06/30/2006', '06/30/2009', '06/30/2009',
        NULL);
INSERT INTO TIMELINE
VALUES ('P103950', '11/21/2007', '03/26/2008', '06/03/2008', '10/13/2008', '09/15/2010', '08/31/2012', '08/31/2014',
        NULL);
INSERT INTO TIMELINE
VALUES ('P001657', '02/18/1988', '10/17/1993', '06/09/1994', '12/07/1994', '07/21/1997', '12/31/2000', '06/30/2001',
        NULL);
INSERT INTO TIMELINE
VALUES ('P078408', '03/21/2002', '09/16/2002', '03/06/2003', '06/02/2003', '03/31/2008', '03/01/2008', '09/01/2009',
        NULL);
INSERT INTO TIMELINE
VALUES ('P130878', '07/20/2012', '11/30/2012', '12/13/2012', '03/28/2013', '08/31/2015', '06/30/2016', '04/30/2018',
        NULL);
INSERT INTO TIMELINE
VALUES ('P146804', '07/24/2014', '01/11/2016', '03/28/2016', '06/24/2016', '06/04/2018', '02/15/2020', '12/31/2022',
        NULL);
INSERT INTO TIMELINE
VALUES ('P108253', '07/15/2008', '03/09/2009', '07/02/2009', '01/29/2010', '06/22/2012', '04/30/2015', '10/30/2016',
        NULL);
INSERT INTO TIMELINE
VALUES ('P065301', '10/01/1998', '06/21/1999', '05/11/2000', '07/07/2000', '11/15/2002', '12/31/2005', '12/30/2007',
        NULL);
INSERT INTO TIMELINE
VALUES ('P074447', '05/16/2002', '04/29/2005', '06/29/2005', '10/13/2005', '02/18/2009', '12/31/2010', '12/31/2011',
        NULL);
INSERT INTO TIMELINE
VALUES ('P088150', '07/13/2004', '10/18/2004', '12/14/2004', '04/25/2005', '07/17/2008', '02/28/2011', '06/30/2013',
        NULL);
INSERT INTO TIMELINE
VALUES ('P097026', '07/23/2008', '09/23/2009', '06/29/2010', '11/08/2012', '12/08/2015', '12/31/2015', '10/31/2017',
        NULL);
INSERT INTO TIMELINE
VALUES ('P121455', '04/22/2010', '04/13/2011', '03/06/2012', '07/30/2013', '02/11/2016', '06/30/2017', '09/30/2020',
        NULL);
INSERT INTO TIMELINE
VALUES ('P133045', '09/17/2012', '09/17/2012', '10/17/2014', '01/21/2015', '12/12/2017', '03/31/2017', '03/31/2021',
        NULL);
INSERT INTO TIMELINE
VALUES ('P066386', '09/27/2001', '03/10/2004', '07/08/2004', '03/30/2005', NULL, '12/31/2009', '12/31/2011', NULL);
INSERT INTO TIMELINE
VALUES ('P149095', '05/12/2014', '09/08/2014', '10/31/2014', '12/11/2014', '11/16/2016', '12/31/2018', '12/31/2018',
        NULL);
INSERT INTO TIMELINE
VALUES ('P122476', '11/23/2010', '03/11/2011', '04/26/2011', '09/22/2011', '12/18/2015', '06/30/2015', '12/31/2019',
        NULL);
INSERT INTO TIMELINE
VALUES ('P078613', '08/25/2003', '02/03/2004', '05/11/2004', '07/06/2004', '12/04/2006', '06/30/2008', '03/31/2009',
        NULL);
INSERT INTO TIMELINE
VALUES ('P108069', '12/17/2007', '02/09/2009', '06/04/2009', '12/15/2009', '06/18/2012', '07/31/2013', '07/31/2014',
        NULL);
INSERT INTO TIMELINE
VALUES ('P133424', '07/10/2013', '09/26/2013', '11/27/2013', '09/19/2014', '10/17/2016', '03/31/2018', '09/30/2021',
        NULL);
INSERT INTO TIMELINE
VALUES ('P146006', '04/17/2013', '11/07/2013', '12/04/2013', '01/17/2014', NULL, '03/31/2016', '03/31/2016', NULL);
INSERT INTO TIMELINE
VALUES ('P070544', '10/18/2005', '02/06/2006', '05/09/2006', '07/20/2006', '03/02/2009', '12/01/2011', '03/30/2012',
        NULL);
INSERT INTO TIMELINE
VALUES ('P002975', '07/02/1990', '04/05/1991', '08/04/1992', '10/26/1992', '05/15/1995', '06/30/1999', '06/30/1999',
        NULL);
INSERT INTO TIMELINE
VALUES ('P044679', '04/15/1998', '07/05/1999', '11/30/1999', '08/01/2000', '09/16/2002', '12/31/2003', '12/31/2006',
        NULL);
INSERT INTO TIMELINE
VALUES ('P050400', '01/15/1999', '09/30/1999', '03/28/2000', '10/03/2000', '10/14/2002', '12/31/2003', '06/30/2005',
        NULL);
INSERT INTO TIMELINE
VALUES ('P082452', '04/04/2005', '10/27/2005', '01/05/2006', '05/10/2006', '09/22/2008', '12/31/2010', '06/30/2012',
        NULL);
INSERT INTO TIMELINE
VALUES ('P147343', '10/22/2013', '11/22/2013', '04/11/2014', '07/17/2014', '05/24/2016', '12/31/2017', '12/31/2018',
        NULL);
INSERT INTO TIMELINE
VALUES ('P152932', '02/10/2015', '06/23/2015', '03/24/2016', '06/24/2016', '06/29/2018', '06/30/2019', '05/31/2021',
        NULL);
INSERT INTO TIMELINE
VALUES ('P087945', '02/04/2005', '04/10/2006', '06/27/2006', '06/29/2007', '01/18/2010', '01/15/2012', '11/15/2013',
        NULL);
INSERT INTO TIMELINE
VALUES ('P143774', '01/28/2013', '07/30/2013', '11/06/2013', '11/07/2013', '07/20/2015', '05/14/2016', '05/14/2017',
        NULL);
INSERT INTO TIMELINE
VALUES ('P036041', '05/15/1994', '01/03/1995', '04/25/1995', '09/25/1995', NULL, '12/31/1999', '12/31/2002', NULL);
INSERT INTO TIMELINE
VALUES ('P004019', '09/08/1993', '01/04/1994', '09/22/1994', '12/20/1994', '11/15/1997', '12/31/2000', '12/31/2000',
        NULL);
INSERT INTO TIMELINE
VALUES ('P085133', '11/18/2003', '09/14/2004', '12/21/2004', '10/27/2005', '05/22/2009', '06/30/2009', '12/31/2015',
        NULL);
INSERT INTO TIMELINE
VALUES ('P077620', '03/20/2002', '05/02/2002', '06/25/2002', '02/12/2003', '12/08/2006', '04/30/2008', '04/30/2011',
        NULL);
INSERT INTO TIMELINE
VALUES ('P051855', '08/15/1997', '01/16/1998', '06/02/1998', '02/03/1999', '05/28/2002', '06/30/2001', '09/30/2005',
        NULL);
INSERT INTO TIMELINE
VALUES ('P077778', '02/19/2003', '04/02/2003', '06/24/2003', '02/11/2004', '01/25/2007', '09/30/2007', '03/31/2013',
        NULL);
INSERT INTO TIMELINE
VALUES ('P144952', '06/10/2013', '01/28/2014', '04/02/2014', '10/09/2014', '09/30/2016', '09/30/2019', '03/31/2021',
        NULL);
INSERT INTO TIMELINE
VALUES ('P092484', '01/31/2005', '11/08/2005', '03/21/2006', '11/15/2006', '06/04/2010', '07/10/2011', '01/31/2014',
        NULL);
INSERT INTO TIMELINE
VALUES ('P075399', '02/04/2002', '03/10/2003', '05/22/2003', '09/04/2003', '12/22/2006', '02/28/2009', '10/31/2013',
        NULL);
INSERT INTO TIMELINE
VALUES ('P069939', '06/07/1999', '12/06/1999', '03/21/2000', '07/17/2000', '12/27/2002', '12/31/2004', '12/15/2006',
        NULL);
INSERT INTO TIMELINE
VALUES ('P105143', '03/07/2007', '03/30/2007', '01/17/2008', '01/17/2008', '11/05/2009', '09/30/2010', '09/30/2011',
        NULL);
INSERT INTO TIMELINE
VALUES ('P129332', '11/04/2011', '02/28/2012', '01/10/2013', '03/27/2013', NULL, '03/31/2016', '06/30/2020', NULL);
INSERT INTO TIMELINE
VALUES ('P149913', '11/19/2014', '07/20/2015', '09/30/2015', '05/06/2016', '06/30/2019', '12/31/2020', '11/30/2022',
        NULL);
INSERT INTO TIMELINE
VALUES ('P066100', '07/19/1999', '04/01/2002', '06/18/2002', '12/24/2002', '06/14/2004', '06/30/2006', '06/30/2009',
        NULL);
INSERT INTO TIMELINE
VALUES ('P146997', '05/20/2015', '12/07/2015', '03/28/2016', '07/27/2016', '07/13/2018', '06/30/2019', '07/30/2021',
        NULL);
INSERT INTO TIMELINE
VALUES ('P063081', '09/23/2005', '12/19/2005', '02/16/2006', '08/03/2006', '01/20/2009', '03/01/2010', '03/01/2012',
        NULL);
INSERT INTO TIMELINE
VALUES ('P043446', '10/13/1995', '08/01/1996', '12/05/1996', '02/07/1997', '09/17/1998', '06/30/2001', '06/30/2002',
        NULL);
INSERT INTO TIMELINE
VALUES ('P037960', '06/23/1994', '04/05/1996', '07/30/1996', '08/01/1996', '06/01/2001', '08/01/2000', '12/31/2002',
        NULL);
INSERT INTO TIMELINE
VALUES ('P101614', '04/06/2009', '07/15/2009', '02/04/2010', '06/17/2011', '10/30/2013', '06/30/2013', '12/31/2016',
        NULL);
INSERT INTO TIMELINE
VALUES ('P071063', '05/02/2002', '03/26/2003', '05/15/2003', '08/28/2003', '03/07/2007', '12/31/2007', '12/31/2013',
        NULL);
INSERT INTO TIMELINE
VALUES ('P082916', '03/04/2004', '03/29/2005', '06/16/2005', '01/03/2006', '02/12/2009', '06/30/2010', '12/31/2013',
        NULL);
INSERT INTO TIMELINE
VALUES ('P064508', '06/07/1999', '04/12/2001', '06/06/2002', '10/02/2002', '11/17/2008', '12/31/2007', '06/30/2012',
        NULL);
INSERT INTO TIMELINE
VALUES ('P122998', '02/28/2011', '12/04/2012', '09/13/2013', '03/19/2014', '06/14/2016', '12/31/2017', '12/31/2017',
        NULL);
INSERT INTO TIMELINE
VALUES ('P069864', '06/05/2001', '03/25/2003', '06/10/2003', '09/04/2003', '07/04/2005', '01/01/2007', '01/01/2007',
        NULL);
INSERT INTO TIMELINE
VALUES ('P099840', '08/14/2006', '12/09/2008', '05/14/2009', '02/12/2010', '09/10/2012', '08/31/2014', '03/31/2015',
        NULL);
INSERT INTO TIMELINE
VALUES ('P035759', '06/17/1994', '04/10/1995', '09/21/1995', '05/01/1996', '12/15/1998', '06/30/2000', '12/31/2002',
        NULL);
INSERT INTO TIMELINE
VALUES ('P049174', '01/23/1997', '07/31/1997', '02/24/1998', '07/27/1999', '10/17/2002', '06/30/2002', '12/31/2004',
        NULL);
INSERT INTO TIMELINE
VALUES ('P090389', '12/16/2005', '09/04/2007', '01/08/2008', '10/23/2008', '03/14/2011', '06/30/2013', '12/31/2014',
        NULL);
INSERT INTO TIMELINE
VALUES ('P006029', '10/10/1990', '03/11/1991', '06/25/1991', '12/10/1991', NULL, '06/30/1995', '06/30/1997', NULL);
INSERT INTO TIMELINE
VALUES ('P037049', '08/19/1994', '05/18/1995', '11/21/1995', '04/09/1997', NULL, '06/30/2001', '12/31/2006', NULL);
INSERT INTO TIMELINE
VALUES ('P006160', '02/01/1986', '02/01/1987', '05/28/1987', '12/15/1987', NULL, '06/30/1992', '06/30/1994', NULL);
INSERT INTO TIMELINE
VALUES ('P006189', '05/18/1990', '10/29/1990', '06/26/1991', '12/16/1991', '05/15/1994', '06/30/1996', '12/31/1997',
        NULL);
INSERT INTO TIMELINE
VALUES ('P040110', '05/09/1996', '02/16/1997', '08/05/1997', '06/04/1998', '03/19/2001', '01/31/2002', '03/31/2003',
        NULL);
INSERT INTO TIMELINE
VALUES ('P006394', '06/11/1984', '10/07/1985', '06/19/1986', '12/16/1986', NULL, '12/31/1990', '12/31/1993', NULL);
INSERT INTO TIMELINE
VALUES ('P073294', '03/06/2001', '04/16/2001', '05/24/2001', '12/19/2002', '09/15/2004', '12/31/2005', '12/31/2008',
        NULL);
INSERT INTO TIMELINE
VALUES ('P006669', '06/08/1990', '05/22/1991', '10/03/1991', '01/22/1992', '06/15/1995', '06/30/1998', '06/30/1998',
        NULL);
INSERT INTO TIMELINE
VALUES ('P069259', '01/02/2001', '11/26/2001', '02/19/2002', '08/29/2002', NULL, '12/31/2006', '06/30/2007', NULL);
INSERT INTO TIMELINE
VALUES ('P103441', '01/08/2007', '07/11/2007', '08/28/2007', '02/27/2008', '03/30/2010', '06/30/2013', '06/30/2014',
        NULL);
INSERT INTO TIMELINE
VALUES ('P006889', '12/15/1992', '06/07/1993', '12/07/1993', '05/10/1994', NULL, '06/30/2000', '03/31/2001', NULL);
INSERT INTO TIMELINE
VALUES ('P040109', '12/13/1999', '10/11/2000', '03/22/2001', '07/18/2001', '10/08/2004', '10/31/2006', '12/31/2009',
        NULL);
INSERT INTO TIMELINE
VALUES ('P106628', '09/29/2009', '11/03/2009', '12/17/2009', '01/13/2010', '08/19/2011', '12/31/2012', '12/31/2014',
        NULL);
INSERT INTO TIMELINE
VALUES ('P007071', '10/15/1984', '01/15/1985', '04/16/1985', '07/30/1986', NULL, '09/30/1989', '03/31/1993', NULL);
INSERT INTO TIMELINE
VALUES ('P007136', '02/03/1994', '06/27/1994', '12/13/1994', '05/11/1995', '04/30/1997', '06/30/2000', '03/31/2001',
        NULL);
INSERT INTO TIMELINE
VALUES ('P074218', '10/18/2001', '01/14/2002', '03/26/2002', '09/25/2003', '06/17/2008', '03/01/2007', '02/27/2009',
        NULL);
INSERT INTO TIMELINE
VALUES ('P007164', '11/28/1994', '12/04/1995', '09/03/1996', '03/11/1997', '09/10/1999', '08/31/2001', '08/31/2007',
        NULL);
INSERT INTO TIMELINE
VALUES ('P095314', '09/10/2009', '10/19/2009', '11/24/2009', '05/24/2011', '02/11/2013', '12/31/2014', '09/30/2016',
        NULL);
INSERT INTO TIMELINE
VALUES ('P007213', '10/21/1994', '03/31/1995', '05/30/1995', '04/22/1996', NULL, '06/30/1999', '06/30/1999', NULL);
INSERT INTO TIMELINE
VALUES ('P048657', '07/30/1997', '09/17/1997', '12/23/1997', '11/19/1998', NULL, '09/30/2002', '09/30/2002', NULL);
INSERT INTO TIMELINE
VALUES ('P066175', '09/28/2001', '10/01/2001', '03/14/2002', '04/18/2003', '11/08/2005', '09/30/2006', '06/30/2011',
        NULL);
INSERT INTO TIMELINE
VALUES ('P034607', '09/18/1992', '04/14/1995', '02/08/1996', '07/11/1996', '12/31/1997', '06/30/2000', '06/30/2000',
        NULL);
INSERT INTO TIMELINE
VALUES ('P060785', '02/15/2000', '04/25/2000', '09/12/2000', '04/03/2001', '07/07/2003', '08/31/2004', '09/30/2006',
        NULL);
INSERT INTO TIMELINE
VALUES ('P110050', '02/23/2009', '10/06/2011', '12/06/2011', '12/15/2011', '06/02/2014', '12/31/2015', '12/31/2015',
        NULL);
INSERT INTO TIMELINE
VALUES ('P007457', '01/28/1987', '11/14/1990', '06/27/1991', '09/17/1991', NULL, '06/30/1998', '06/30/1998', NULL);
INSERT INTO TIMELINE
VALUES ('P007490', '08/23/1993', '09/15/1995', '09/03/1996', '04/07/1997', '06/29/1999', '12/31/2001', '06/30/2003',
        NULL);
INSERT INTO TIMELINE
VALUES ('P035080', '03/29/1994', '12/23/1994', '03/16/1995', '05/12/1995', '07/01/1998', '12/31/2000', '12/31/2001',
        NULL);
INSERT INTO TIMELINE
VALUES ('P049296', '10/06/1999', '11/19/1999', '01/20/2000', '06/14/2000', '12/20/2000', '02/02/2003', '06/30/2004',
        NULL);
INSERT INTO TIMELINE
VALUES ('P078891', '04/29/2003', '01/26/2004', '03/25/2004', '10/13/2004', '08/09/2006', '06/30/2008', '12/31/2009',
        NULL);
INSERT INTO TIMELINE
VALUES ('P111795', '03/29/2010', '08/17/2010', '12/07/2010', '05/06/2011', '10/23/2014', '12/31/2015', '08/31/2020',
        NULL);
INSERT INTO TIMELINE
VALUES ('P121492', '09/29/2010', '01/25/2011', '03/03/2011', '03/07/2012', '09/15/2014', '09/30/2016', '06/30/2020',
        NULL);
INSERT INTO TIMELINE
VALUES ('P100635', '05/02/2007', '03/17/2008', '05/27/2008', '06/18/2009', '03/21/2011', '06/30/2012', '02/28/2014',
        NULL);
INSERT INTO TIMELINE
VALUES ('P057601', '11/11/1998', '05/16/1999', '06/29/1999', '07/18/2000', NULL, '06/30/2004', '06/30/2006', NULL);
INSERT INTO TIMELINE
VALUES ('P064921', '10/26/1999', '03/13/2000', '02/06/2001', '07/17/2001', '05/15/2004', '02/28/2006', '02/28/2009',
        NULL);
INSERT INTO TIMELINE
VALUES ('P050706', '02/05/1998', '06/18/1999', '04/20/2000', '11/29/2000', '10/07/2003', '12/31/2005', '06/30/2010',
        NULL);
INSERT INTO TIMELINE
VALUES ('P117363', '09/30/2009', '07/23/2010', '12/20/2010', '01/19/2011', '12/31/2014', '12/31/2015', '12/31/2015',
        NULL);
INSERT INTO TIMELINE
VALUES ('P077417', '02/22/2002', '03/01/2002', '04/04/2002', '06/07/2002', '01/30/2004', '09/30/2005', '09/30/2005',
        NULL);
INSERT INTO TIMELINE
VALUES ('P082610', '05/14/2003', '05/23/2003', '06/24/2003', '07/15/2003', NULL, '03/31/2006', '09/30/2008', NULL);
INSERT INTO TIMELINE
VALUES ('P084736', '08/11/2004', '10/05/2004', '01/27/2005', '05/02/2005', '10/19/2006', '06/30/2009', '06/30/2009',
        NULL);
INSERT INTO TIMELINE
VALUES ('P099980', '12/12/2006', '03/02/2007', '05/29/2007', '07/11/2007', '04/20/2009', '12/31/2010', '12/31/2011',
        NULL);
INSERT INTO TIMELINE
VALUES ('P120427', '09/20/2010', '05/05/2011', '06/23/2011', '08/09/2011', '11/01/2013', '12/31/2014', '12/31/2017',
        NULL);
INSERT INTO TIMELINE
VALUES ('P159655', '06/07/2017', '08/24/2017', '12/19/2017', '01/01/2018', '06/30/2020', '12/28/2022', '12/28/2022',
        NULL);
INSERT INTO TIMELINE
VALUES ('P117248', '10/29/2008', '05/28/2009', '09/23/2009', '10/29/2009', NULL, '07/31/2014', '07/31/2014', NULL);
INSERT INTO TIMELINE
VALUES ('P094193', '01/10/2005', '02/07/2005', '03/15/2005', '04/04/2005', '01/15/2007', '12/31/2008', '12/31/2009',
        NULL);
INSERT INTO TIMELINE
VALUES ('P145317', '10/10/2013', '02/25/2014', '06/26/2014', '10/02/2014', '04/10/2017', '07/31/2019', '07/31/2022',
        NULL);
INSERT INTO TIMELINE
VALUES ('P125770', '03/24/2011', '06/30/2011', '08/16/2011', '10/31/2011', '07/30/2013', '06/30/2015', '06/30/2016',
        NULL);
INSERT INTO TIMELINE
VALUES ('P036015', '04/05/1993', '03/19/1995', '09/17/1996', '02/18/1997', '12/12/2000', '06/30/2002', '05/31/2005',
        NULL);
INSERT INTO TIMELINE
VALUES ('P076872', '07/10/2002', '12/20/2004', '09/06/2005', '11/08/2005', '02/29/2008', '12/31/2010', '12/31/2014',
        NULL);
INSERT INTO TIMELINE
VALUES ('P174620', '05/07/2021', '12/15/2021', '05/05/2022', '08/05/2022', NULL, '12/31/2026', '12/31/2026', NULL);
INSERT INTO TIMELINE
VALUES ('P165000', '09/29/2017', '04/04/2019', '07/16/2019', '08/01/2019', '09/15/2021', '10/31/2024', '10/31/2024',
        NULL);
INSERT INTO TIMELINE
VALUES ('P174822', '07/28/2020', '06/14/2021', '04/14/2022', '07/15/2022', NULL, '06/30/2028', '06/30/2028', NULL);
INSERT INTO TIMELINE
VALUES ('P163540', '07/31/2017', '07/31/2017', '06/27/2018', '05/07/2019', '12/18/2020', '12/31/2022', '06/30/2023',
        NULL);
INSERT INTO TIMELINE
VALUES ('P164807', '11/22/2017', '06/18/2018', '10/23/2018', '12/21/2018', '01/23/2019', '02/28/2023', '02/28/2023',
        NULL);
INSERT INTO TIMELINE
VALUES ('P151492', '12/11/2014', '03/27/2015', '07/07/2015', '09/09/2015', '05/08/2017', '06/30/2018', '06/30/2023',
        NULL);
INSERT INTO TIMELINE
VALUES ('P176761', '08/31/2021', '12/16/2021', '02/24/2022', '06/13/2022', NULL, '12/31/2026', '12/31/2026', NULL);
INSERT INTO TIMELINE
VALUES ('P167534', '08/23/2018', '12/04/2018', '03/14/2019', '06/21/2019', '05/30/2022', '08/31/2025', '08/31/2025',
        NULL);
INSERT INTO TIMELINE
VALUES ('P163131', '08/23/2017', '03/23/2018', '05/30/2018', '10/01/2018', '01/29/2021', '09/25/2023', '09/25/2023',
        NULL);
INSERT INTO TIMELINE
VALUES ('P161969', '08/23/2017', '03/23/2018', '05/30/2018', '10/01/2018', '01/31/2021', '09/25/2023', '03/25/2025',
        NULL);
INSERT INTO TIMELINE
VALUES ('P176366', '06/29/2021', '06/15/2022', '12/14/2022', '01/26/2023', NULL, '09/30/2027', '09/30/2027', NULL);
INSERT INTO TIMELINE
VALUES ('P150381', '09/11/2014', '02/24/2015', '06/01/2015', '05/10/2016', '10/01/2019', '06/30/2021', '06/30/2025',
        NULL);
INSERT INTO TIMELINE
VALUES ('P172352', '10/29/2019', '02/14/2020', '03/26/2020', '12/18/2020', '03/27/2023', '03/31/2026', '03/31/2026',
        NULL);
INSERT INTO TIMELINE
VALUES ('P157531', '02/10/2016', '12/11/2016', '03/24/2017', '07/07/2017', '06/10/2019', '12/31/2021', '12/31/2023',
        NULL);
INSERT INTO TIMELINE
VALUES ('P169959', '04/09/2019', '12/06/2019', '02/06/2020', '01/11/2021', '09/30/2022', '04/30/2025', '04/30/2025',
        NULL);
INSERT INTO TIMELINE
VALUES ('P151357', '04/12/2016', '05/05/2016', '12/20/2016', '12/28/2016', '01/06/2020', '11/30/2021', '11/30/2024',
        NULL);
INSERT INTO TIMELINE
VALUES ('P162850', '02/02/2017', '12/07/2017', '06/01/2018', '07/19/2018', '05/04/2020', '06/30/2022', '06/30/2023',
        NULL);
INSERT INTO TIMELINE
VALUES ('P167491', '07/14/2018', '11/26/2018', '03/01/2019', '07/03/2019', '07/08/2021', '06/30/2024', '06/30/2024',
        NULL);
INSERT INTO TIMELINE
VALUES ('P156687', '07/26/2016', '01/04/2017', '05/17/2017', '07/11/2017', '10/31/2019', '09/30/2022', '06/30/2023',
        NULL);
INSERT INTO TIMELINE
VALUES ('P156869', '07/26/2016', '10/03/2017', '05/01/2018', '07/26/2018', '06/05/2021', '03/31/2024', '03/31/2024',
        NULL);
INSERT INTO TIMELINE
VALUES ('P157198', '11/16/2015', '01/09/2017', '06/15/2017', '09/25/2017', '03/16/2020', '09/30/2022', '09/30/2023',
        NULL);
INSERT INTO TIMELINE
VALUES ('P166578', '04/26/2018', '09/26/2018', '02/21/2019', '05/24/2019', '11/29/2021', '03/31/2024', '03/31/2024',
        NULL);
INSERT INTO TIMELINE
VALUES ('P166923', '04/26/2018', '11/19/2018', '03/07/2019', '08/20/2019', '09/30/2022', '06/30/2024', '06/30/2024',
        NULL);
INSERT INTO TIMELINE
VALUES ('P164783', '09/19/2017', '03/16/2018', '06/27/2018', '08/24/2018', '01/13/2020', '07/30/2021', '07/16/2023',
        NULL);

----COST
INSERT INTO COST
VALUES ('P000301', '14622960', '15900000', '5970000', '14310000', '615000', NULL);
INSERT INTO COST
VALUES ('P001657', '24542098', '26620000', '5840000', '19780000', '1414105', NULL);
INSERT INTO COST
VALUES ('P002975', '26112837', '33900000', '13300000', '30330000', '566700', NULL);
INSERT INTO COST
VALUES ('P004019', '16917741', '23990000', '10490000', '18740000', '621700', NULL);
INSERT INTO COST
VALUES ('P006029', '24135940', '31500000', '7615000', '23000000', '372000', NULL);
INSERT INTO COST
VALUES ('P006160', '20203284', '24982000', '14247000', '11857000', '262500', NULL);
INSERT INTO COST
VALUES ('P006189', '23092940', '26150000', '12170000', '10990000', '390300', NULL);
INSERT INTO COST
VALUES ('P006394', '17572721', '23995000', '17900000', '23990000', '900000', NULL);
INSERT INTO COST
VALUES ('P006669', '22427216', '22600000', '3900000', '15290000', '355300', NULL);
INSERT INTO COST
VALUES ('P006889', '40331731', '54270000', '16000000', '29020000', '578200', NULL);
INSERT INTO COST
VALUES ('P007071', '4243378', '6000000', '1245000', '6000000', NULL, NULL);
INSERT INTO COST
VALUES ('P007136', '17265740', '20920000', '12060000', '18120000', '765600', NULL);
INSERT INTO COST
VALUES ('P007164', '18705847', '22250000', '1550000', '22250000', '1420290', NULL);
INSERT INTO COST
VALUES ('P007213', '7481875', '10250000', '5800000', '9400000', '891100', NULL);
INSERT INTO COST
VALUES ('P007457', '13980858', '15000000', '5500000', '11500000', '493500', NULL);
INSERT INTO COST
VALUES ('P007490', '27478550', '33050000', '3870000', '27120000', '675350', NULL);
INSERT INTO COST
VALUES ('P034607', '9050619', '13010000', '5650000', '8740000', '361210', NULL);
INSERT INTO COST
VALUES ('P035080', '24688910', '28470000', '8400000', '21530000', '325620', NULL);
INSERT INTO COST
VALUES ('P035759', '67758314', '78460000', '64680000', '44180000', '1642810', NULL);
INSERT INTO COST
VALUES ('P036015', '33265738', '34020000', '21380000', '28000000', '965800', NULL);
INSERT INTO COST
VALUES ('P036041', '62337475', '76500000', '51580000', '47490000', '144000', NULL);
INSERT INTO COST
VALUES ('P037049', '7353308', '10570000', '3000000', '10280000', '772270', NULL);
INSERT INTO COST
VALUES ('P037960', '15325081', '17650000', '13680000', '14670000', '753870', NULL);
INSERT INTO COST
VALUES ('P040109', '54562737', '59230000', '22000000', '35470000', '1076540', NULL);
INSERT INTO COST
VALUES ('P040110', '18082785', '18580000', '6370000', '14010000', '493300', NULL);
INSERT INTO COST
VALUES ('P043446', '10301336', '10390000', '7900000', '7260000', '311180', NULL);
INSERT INTO COST
VALUES ('P044679', '51454638', '70900000', '40600000', '50240000', '1475690', NULL);
INSERT INTO COST
VALUES ('P045588', '26227739', '33740000', '19880000', '19030000', '525650', NULL);
INSERT INTO COST
VALUES ('P048657', '14200645', '17540000', '9440000', '15560000', '260200', NULL);
INSERT INTO COST
VALUES ('P049174', '24402750', '27240000', '25191000', '16400000', '595620', NULL);
INSERT INTO COST
VALUES ('P049296', '14855187', '22100000', '12220000', '20200000', '578100', NULL);
INSERT INTO COST
VALUES ('P050400', '30356268', '39380000', '6580000', '28190000', '778370', NULL);
INSERT INTO COST
VALUES ('P050706', '39189741', '44000000', '19000000', '31670000', '1915070', NULL);
INSERT INTO COST
VALUES ('P051855', '4507494', '5340000', '4610000', '5340000', '455900', NULL);
INSERT INTO COST
VALUES ('P057601', '17251749', '17510000', '4510000', '12280000', '705820', NULL);
INSERT INTO COST
VALUES ('P057995', '15249833', '20820000', '7130000', '19480000', '1063230', NULL);
INSERT INTO COST
VALUES ('P057998', '2802283', '2880000', '610000', '2880000', '184425', NULL);
INSERT INTO COST
VALUES ('P060785', '17082777', '22350000', '7660000', '20160000', '873870', NULL);
INSERT INTO COST
VALUES ('P063081', '14189284', '15000000', '0', '4200000', '1070810', NULL);
INSERT INTO COST
VALUES ('P064508', '645595047', '663000000', '576000000', '229300000', '1863010', NULL);
INSERT INTO COST
VALUES ('P064921', '6604932', '6950000', '1790000', '6950000', '1256946', NULL);
INSERT INTO COST
VALUES ('P065301', '34336678', '37630000', '3880000', '19280000', '867940', NULL);
INSERT INTO COST
VALUES ('P066100', '13290848', '13350000', '6200000', '11230000', '1022759', NULL);
INSERT INTO COST
VALUES ('P066175', '40102225', '50550000', '20000000', '44753000', '695580', NULL);
INSERT INTO COST
VALUES ('P066386', '16303983', '19429954', '3000000', '19429000', '1055270', NULL);
INSERT INTO COST
VALUES ('P066490', '12765198', '14020000', '4670000', '13620000', '306300', NULL);
INSERT INTO COST
VALUES ('P069259', '27131494', '36000000', '18750478', '23230000', '505600', NULL);
INSERT INTO COST
VALUES ('P069864', '3444340', '4880000', '1200000', '4880000', '750470', NULL);
INSERT INTO COST
VALUES ('P069939', '7931980', '8820000', '6530000', '8820000', '872570', NULL);
INSERT INTO COST
VALUES ('P070544', '108821327', '145600000', '9500000', '22150000', '1183696', NULL);
INSERT INTO COST
VALUES ('P071063', '6474418', '9000000', '6750000', '3960000', '1618000', NULL);
INSERT INTO COST
VALUES ('P073294', '8683744', '10440000', '0', '7960000', '417460', NULL);
INSERT INTO COST
VALUES ('P074218', '11694563', '12730000', '8030000', '7890000', '817460', NULL);
INSERT INTO COST
VALUES ('P074447', '20748732', '21170000', '11300000', '17887000', '2138940', NULL);
INSERT INTO COST
VALUES ('P074448', '29860049', '35640000', '8500000', '35640000', '1146620', NULL);
INSERT INTO COST
VALUES ('P075399', '59496129', '71450000', '53300000', '36730000', '1182150', NULL);
INSERT INTO COST
VALUES ('P076872', '71809636', '96200000', '50200000', '66920000', '2181290', NULL);
INSERT INTO COST
VALUES ('P077417', '11268843', '11390000', '4070000', '11460000', '386000', NULL);
INSERT INTO COST
VALUES ('P077620', '12803618', '13271000', '3500000', '10570000', '82842819', NULL);
INSERT INTO COST
VALUES ('P077778', '6834698', '7859000', '5500000', '7620000', '558920', NULL);
INSERT INTO COST
VALUES ('P078408', '25805377', '28370000', '6000000', '27400000', '1018760', NULL);
INSERT INTO COST
VALUES ('P078613', '18300569', '24353700', '5300000', '25060000', '1383770', NULL);
INSERT INTO COST
VALUES ('P078627', '23745573', '27530000', '11590000', '27200000', '898390', NULL);
INSERT INTO COST
VALUES ('P078891', '33193866', '36100000', '15000000', '35940000', '645930', NULL);
INSERT INTO COST
VALUES ('P082452', '27704994', '30000000', '21800000', '26330000', '370190', NULL);
INSERT INTO COST
VALUES ('P082610', '10729375', '11900000', '3000000', '9050000', '515712', NULL);
INSERT INTO COST
VALUES ('P082916', '11223351', '12031000', '7050000', '8500000', '1547110', NULL);
INSERT INTO COST
VALUES ('P084160', '5190016', '5600000', '1200000', '4120000', '1445570', NULL);
INSERT INTO COST
VALUES ('P084736', '21011451', '27970000', '14000000', '27970000', '366470', NULL);
INSERT INTO COST
VALUES ('P085133', '68917597', '69618118', '66300000', '69587176', '3084333', NULL);
INSERT INTO COST
VALUES ('P087945', '23188819', '30300000', '10500000', '7170000', '1053180', NULL);
INSERT INTO COST
VALUES ('P088150', '172213771', '179220000', '60000000', '85290000', '2830400', NULL);
INSERT INTO COST
VALUES ('P090265', '15979646', '20200000', '5000000', '12840000', '1298170', NULL);
INSERT INTO COST
VALUES ('P090389', '62296544', '65000000', '59000000', '4178000', '1147705', NULL);
INSERT INTO COST
VALUES ('P090567', '33614114', '37360000', '1795000', '10710000', '1609343', NULL);
INSERT INTO COST
VALUES ('P092484', '27602715', '32100000', '21000000', '31317984.59', '2527471', NULL);
INSERT INTO COST
VALUES ('P093610', '88252452', '102200000', '20000000', '78991990', '2059895', NULL);
INSERT INTO COST
VALUES ('P094193', '13860512', '16100000', '6000000', '16000000', '577300', NULL);
INSERT INTO COST
VALUES ('P095314', '17625717', '20060000', '11500000', '15360000', '987770', NULL);
INSERT INTO COST
VALUES ('P097026', '101675650', '120000000', '50000000', '64270000', '1529860', NULL);
INSERT INTO COST
VALUES ('P099840', '7770343', '11270000', '1100000', '4960000', '569786', NULL);
INSERT INTO COST
VALUES ('P099980', '30370630', '33400000', '12000000', '26800000', '226140', NULL);
INSERT INTO COST
VALUES ('P100635', '6726948', '7200000', '5700000', '7200000', '1013608', NULL);
INSERT INTO COST
VALUES ('P101614', '7126240', '7490000', '5500000', '7490000', '807000', NULL);
INSERT INTO COST
VALUES ('P102376', '4223189', '5260000', '1800000', '5080000', '1241844', NULL);
INSERT INTO COST
VALUES ('P103441', '45994349', '46600000', '21000000', '24680000', '942171', NULL);
INSERT INTO COST
VALUES ('P103950', '18293152', '25200000', '6000000', '23742000', '1005790', NULL);
INSERT INTO COST
VALUES ('P104041', '94897807', '113850000', '66400000', '107060000', '1744070', NULL);
INSERT INTO COST
VALUES ('P105143', '6933339', '7421000', '1551000', '5170000', NULL, NULL);
INSERT INTO COST
VALUES ('P106628', '29028759', '33850000', '18200000', '20420000', '1004326', NULL);
INSERT INTO COST
VALUES ('P107355', '13910840', '18000000', '8000000', '16860000', '708860', NULL);
INSERT INTO COST
VALUES ('P108069', '17924022', '20930000', '5980000', '1230000', '1056195', NULL);
INSERT INTO COST
VALUES ('P108253', '9638164', '10000000', '3000000', '9920000', '1163500', NULL);
INSERT INTO COST
VALUES ('P109775', '3207247', '3700000', '1500000', '3600000', '100000', NULL);
INSERT INTO COST
VALUES ('P110050', '5278233', '7360000', '1720000', '4950000', '1020260', NULL);
INSERT INTO COST
VALUES ('P111795', '30972664', '38350000', '17000000', '38350000', NULL, NULL);
INSERT INTO COST
VALUES ('P117248', '51590155', '52500000', '49000000', '51325637', NULL, NULL);
INSERT INTO COST
VALUES ('P117275', '14771558', '15610000', '7400000', '15340000', NULL, NULL);
INSERT INTO COST
VALUES ('P117363', '16238211', '17000000', '6550000', '6450000', NULL, NULL);
INSERT INTO COST
VALUES ('P120427', '81331234', '114070000', '20000000', '109210000', '781066', NULL);
INSERT INTO COST
VALUES ('P121455', '239228992', '289720000', '10000000', '253780000', NULL, NULL);
INSERT INTO COST
VALUES ('P121492', '44396453', '55000000', '34240888', '49000000', NULL, NULL);
INSERT INTO COST
VALUES ('P122476', '31155249', '44992904', '19000000', '40594911', '1088403', NULL);
INSERT INTO COST
VALUES ('P122998', '23404875', '28500000', '1000000', '25505500', '1118983', NULL);
INSERT INTO COST
VALUES ('P125770', '3696951', '4300000', '3500000', '4281000', NULL, NULL);
INSERT INTO COST
VALUES ('P127319', '24273452', '25644048', '10000000', '25491345', '802934', NULL);
INSERT INTO COST
VALUES ('P129332', '4795328', '5930000', '3876490', '5380000', NULL, NULL);
INSERT INTO COST
VALUES ('P130878', '18146387', '19000000', '9200000', '10900341', NULL, NULL);
INSERT INTO COST
VALUES ('P133045', '44928453', '65110000', '20000000', '54200000', NULL, NULL);
INSERT INTO COST
VALUES ('P133424', '20151579', '26600000', '9000000', '23920000', NULL, NULL);
INSERT INTO COST
VALUES ('P143197', '3706986', '5241043', '3375000', '4762822', '654391', NULL);
INSERT INTO COST
VALUES ('P143774', '13822988', '18796197', '3000000', '18349597', '162000', NULL);
INSERT INTO COST
VALUES ('P144952', '34292483', '47470000', '12000000', '37200000', NULL, NULL);
INSERT INTO COST
VALUES ('P145317', '12933921', '18500000', '4400000', '10780000', NULL, NULL);
INSERT INTO COST
VALUES ('P145747', '69857484', '71640000', '6000000', '66360000', '1821300', NULL);
INSERT INTO COST
VALUES ('P146006', '3723206', '4500000', '540000', '4497940', '191040', NULL);
INSERT INTO COST
VALUES ('P146804', '19415700', '24800000', '2000000', '19030000', NULL, NULL);
INSERT INTO COST
VALUES ('P146997', '7621294', '10000000', '3450000', '8590000', NULL, NULL);
INSERT INTO COST
VALUES ('P147343', '16487880', '22000000', '7800000', '22000000', '2024913.59', NULL);
INSERT INTO COST
VALUES ('P149095', '95278238', '100000000', '40000000', '93380000', '816444', NULL);
INSERT INTO COST
VALUES ('P149913', '16391134', '20300000', '19000000', '18460000', NULL, NULL);
INSERT INTO COST
VALUES ('P150381', '25660000', NULL, '8800000', '17990000', NULL, NULL);
INSERT INTO COST
VALUES ('P150827', '4087012', '5000000', '1100000', '4870000', NULL, NULL);
INSERT INTO COST
VALUES ('P150922', '28537208', '33000000', '22450000', '28690000', '1082000', NULL);
INSERT INTO COST
VALUES ('P151357', '41500000', NULL, '27500000', '4260000', NULL, NULL);
INSERT INTO COST
VALUES ('P151447', '42851958', '47350000', '32700000', '47060000', NULL, NULL);
INSERT INTO COST
VALUES ('P151492', '50000000', NULL, '9500000', '43630000', NULL, NULL);
INSERT INTO COST
VALUES ('P152932', '7107742', NULL, '6800000', '9850000', NULL, NULL);
INSERT INTO COST
VALUES ('P155121', '22271548', '30000000', '5500000', '30000000', NULL, NULL);
INSERT INTO COST
VALUES ('P156687', '36000000', NULL, '10000000', '30790000', NULL, NULL);
INSERT INTO COST
VALUES ('P156869', '21700000', NULL, '10000000', '11560000', NULL, NULL);
INSERT INTO COST
VALUES ('P157198', '31500000', NULL, '20000000', '20780000', NULL, NULL);
INSERT INTO COST
VALUES ('P157531', '20000000', NULL, '10000000', '13110000', NULL, NULL);
INSERT INTO COST
VALUES ('P159655', '44956589', '46250000', '20000000', '44940000', NULL, NULL);
INSERT INTO COST
VALUES ('P161730', '8919187', '10000000', '2570000', '9600000', '539900', NULL);
INSERT INTO COST
VALUES ('P161969', '16000000', NULL, '2000000', '3580000', NULL, NULL);
INSERT INTO COST
VALUES ('P162850', '3500000', NULL, '500000', '2850000', NULL, NULL);
INSERT INTO COST
VALUES ('P163131', '9000000', NULL, '2000000', '2920000', NULL, NULL);
INSERT INTO COST
VALUES ('P163540', '125000000', NULL, '27000000', '23760000', NULL, NULL);
INSERT INTO COST
VALUES ('P164783', '9000000', NULL, '5000000', '5760000', NULL, NULL);
INSERT INTO COST
VALUES ('P164807', '20000000', NULL, '5000000', '11640000', NULL, NULL);
INSERT INTO COST
VALUES ('P165000', '20990000', NULL, '4500000', '16850000', NULL, NULL);
INSERT INTO COST
VALUES ('P166578', '25200000', NULL, '15000000', '5320000', NULL, NULL);
INSERT INTO COST
VALUES ('P166923', '31580000', NULL, '6300000', '7730000', NULL, NULL);
INSERT INTO COST
VALUES ('P167491', '100000000', NULL, '44850000', '51510000', NULL, NULL);
INSERT INTO COST
VALUES ('P167534', '20000000', NULL, '14750000', '1940000', NULL, NULL);
INSERT INTO COST
VALUES ('P169959', '110000000', NULL, '65000000', '280000', NULL, NULL);
INSERT INTO COST
VALUES ('P172352', '156640000', NULL, '72000000', '5350000', NULL, NULL);
INSERT INTO COST
VALUES ('P174620', '35000000', NULL, '15000000', '0', NULL, NULL);
INSERT INTO COST
VALUES ('P174822', '191500000', NULL, '50000000', '0', NULL, NULL);
INSERT INTO COST
VALUES ('P176366', '24500000', NULL, '15000000', '0', NULL, NULL);
INSERT INTO COST
VALUES ('P176761', '34000000', NULL, '12000000', '0', NULL, NULL);


---FMIS SOLUTION
INSERT INTO FMIS_SOLUTION
VALUES ('S101', 'P073294', 'SIAFI', 'Sistema Integrado de Administração Financeira do Governo Federal',
        'https://www.tesouro.fazenda.gov.br/pt/siafi', 'CS/Web (LDSW : SIAFI);', NULL);
INSERT INTO FMIS_SOLUTION
VALUES ('S103', 'P063081', 'PFMIS', 'Public Financial Management Information System', 'http://fas.ge/en/Completed',
        'LDSW', NULL);
INSERT INTO FMIS_SOLUTION
VALUES ('S105', 'P084160', 'SIGEFI',
        'Système Intégré de Gestion des Finances / Integrated Public Financial Management System',
        'http://www-wds.worldbank.org/external/default/WDSContentServer/WDSP/IB/2008/09/04/000334955_20080904030253/Rendered/PDF/433690PAD0P0841LY10IDA1R20081019311.pdf',
        'LDSW > MS SQL', NULL);
INSERT INTO FMIS_SOLUTION
VALUES ('S107', 'P064921', 'IBMIS', 'Integrated Budget Management Information System',
        'http://www-wds.worldbank.org/external/default/WDSContentServer/WDSP/IB/2010/01/13/000334955_20100113020615/Rendered/PDF/ICR113000P06491C0disclosed011111101.pdf',
        'LDSW > Oracle', NULL);
INSERT INTO FMIS_SOLUTION
VALUES ('S109', 'P057998', 'SIGOF', 'Sistema Integrado de Gestão Orçamental e Financeira',
        'http://www.nosi.cv/index.php?option=com_content&view=article&id=92&Itemid=125&lang=en', 'LDSW > Oracle', NULL);
INSERT INTO FMIS_SOLUTION
VALUES ('S111', 'P002975', 'IFMS', 'Integrated Financial Management System',
        'http://www.finance.go.ug/index.php/ifms.html', 'Oracle', NULL);
INSERT INTO FMIS_SOLUTION
VALUES ('S113', 'P050400', 'IFMIS', 'Integrated Financial Management Information System',
        'http://www.mofnp.gov.zm/index.php?option=com_content&task=view&id=121&Itemid=130', 'SAP', NULL);
INSERT INTO FMIS_SOLUTION
VALUES ('S115', 'P065301', 'GIFMIS', 'Government Integrated Financial Management Information System',
        'http://www.gifmis.gov.ng/gif-mis/index.php?option=com_content&view=article&id=2&Itemid=2', 'SAP + LDSW', NULL);
INSERT INTO FMIS_SOLUTION
VALUES ('S117', 'P176366', 'IFMIS', 'Integrated Financial Management Information System', 'http://www.finance.gov.mk',
        'LDSW', '2025');
INSERT INTO FMIS_SOLUTION
VALUES ('S119', 'P169959', 'SIDAFF', 'Sistema Integrado de Administración Financiera Federal',
        'http://www.hacienda.gob.mx/EGRESOS/contabilidad_gubernamental/manual_contabilidad/index.html', 'COTS', '2024');
INSERT INTO FMIS_SOLUTION
VALUES ('S121', 'P176761', 'FMIS', 'Financial Management Information System',
        'http://www.sudantribune.com/South-Sudan-launches-electronic,39069', 'FreeBalance', '2024');
INSERT INTO FMIS_SOLUTION
VALUES ('S123', 'P167534', 'IFMIS', 'Integrated Financial Management Information System', NULL, NULL, '2024');
INSERT INTO FMIS_SOLUTION
VALUES ('S125', 'P166578', 'e-Kosh', 'Online Treasury Computerisation',
        'http://www.nic.in/projects/e-kosh-online-treasury-computerisatio', 'LDSW', '2023');
INSERT INTO FMIS_SOLUTION
VALUES ('S127', 'P166923', 'e-Kosh / CTS', 'Finance Portal + Core Treasury Sytem',
        'http://www.nic.in/projects/ekosh-finance-portal', 'LDSW', '2023');
INSERT INTO FMIS_SOLUTION
VALUES ('S129', 'P167491', 'IBAS++', 'Integrated Budget and Accounting System',
        'https://ibas.finance.gov.bd/ibas2/Security/Login?ReturnUrl=%2fibas2%2fIntegrated_Budget_and_Accounting_System%2f',
        'LDSW', '2023');
INSERT INTO FMIS_SOLUTION
VALUES ('S131', 'P156869', 'IFMS', 'Integrated Financial Management System',
        'https://ifms.raj.nic.in/webpages/default.aspx', 'LDSW', '2023');
INSERT INTO FMIS_SOLUTION
VALUES ('S133', 'P165000', 'IFMIS', 'Integrated Financial Management Information System',
        'http://www.mof.gov.lr/content.php?sub=98&related=33&res=98&third=98', 'Web (FreeBalance);', '2023');
INSERT INTO FMIS_SOLUTION
VALUES ('S135', 'P163131', 'FMIS', 'Financial Management Information System',
        'https://pefa.org/sites/default/files/assements/comments/MH-Oct12-PFMPR-Public.pdf', '4gov', '2022');
INSERT INTO FMIS_SOLUTION
VALUES ('S137', 'P161969', 'FMIS', 'Financial Management Information System',
        'http://www.mra.fm/pdfs/news_StrategicPlan.pdf', 'American Fundware', '2022');
INSERT INTO FMIS_SOLUTION
VALUES ('S139', 'P159655', 'AFMIS', 'Afghanistan Financial Management Information System',
        'http://mof.gov.af/en/page/1149', 'CS (FreeBalance);', '2022');
INSERT INTO FMIS_SOLUTION
VALUES ('S141', 'P156687', 'OLTIS', 'Online Treasury Information System',
        'http://www.nic.in/projects/oltis-online-treasury-information-system', 'LDSW', '2022');
INSERT INTO FMIS_SOLUTION
VALUES ('S143', 'P157198', 'FinAssam', 'Integrated Financial Management Information System of Assam',
        'https://www.finassam.in/assamfinance/welcome', 'LDWS (open source);', '2022');
INSERT INTO FMIS_SOLUTION
VALUES ('S145', 'P155121', 'SI N@FOLO', 'Financial Management Information System', 'https://tresor.gov.bf',
        'CS (Oracle);', '2021');
INSERT INTO FMIS_SOLUTION
VALUES ('S147', 'P162850', 'BISAN', 'Financial Management Information System', 'http://www.bisan.com/?lang=en',
        'LDSW > MS SQL', '2021');
INSERT INTO FMIS_SOLUTION
VALUES ('S149', 'P164783', 'CTS', 'Core Treasury System', 'http://lmbis.gov.np/', 'LDSW > Oracle', '2021');
INSERT INTO FMIS_SOLUTION
VALUES ('S151', 'P174620', 'FMIS', 'Financial Management Information System', 'https://www.finances.gouv.cf/', 'SIMBA',
        '2021');
INSERT INTO FMIS_SOLUTION
VALUES ('S153', 'P157531', 'SIGFIP', 'Sytème Intégré de Gestion des Finances Publiques (SIGFiP);',
        'http://www-wds.worldbank.org/external/default/WDSContentServer/WDSP/IB/2008/07/10/000333037_20080710023439/Rendered/PDF/446510PUB0HT0P101Official0Use0Only1.pdf',
        'FreeBalance', '2020');
INSERT INTO FMIS_SOLUTION
VALUES ('S155', 'P172352', 'SFP + SIGAF',
        'Sistema de Formulación / Sistema Integrado de Gestión para la Administración Financiera',
        'http://www.hacienda.go.cr/contenido/12668-sigaf-sistema-integrado-de-gestion-de-administracion-financiera',
        'MS SQL + SAP', '2020');
INSERT INTO FMIS_SOLUTION
VALUES ('S157', 'P149913', 'FMIS', 'Financial Management Information System',
        'https://www.yumpu.com/en/document/view/15734776/gfims-inception-report/1 ', NULL, '2020');
INSERT INTO FMIS_SOLUTION
VALUES ('S159', 'P151357', 'IFMIS', 'Integrated Financial Management Information System', NULL, NULL, '2020');
INSERT INTO FMIS_SOLUTION
VALUES ('S161', 'P161730', 'FMIS', 'Financial Management Information System', 'https://www.finances.gouv.cf/', 'SIMBA',
        '2020');
INSERT INTO FMIS_SOLUTION
VALUES ('S163', 'P146997', 'TS', 'Treasury System',
        'http://siteresources.worldbank.org/BELARUSEXTN/Resources/PEFA_Belarus_april_2009_english.pdf', 'LDSW', '2019');
INSERT INTO FMIS_SOLUTION
VALUES ('S165', 'P143197', 'IFMIS', 'Integrated Financial Management Information System',
        'http://www.finance.gov.ls/reforms/ifmis.php', 'CS (Epicor 7.3.5);', '2018');
INSERT INTO FMIS_SOLUTION
VALUES ('S167', 'P144952', 'FMIS', 'Financial Management Information System',
        'http://www.pefa.org/en/assessment/mm-mar12-pfmpr-public-en', 'CS (LDSW);', '2018');
INSERT INTO FMIS_SOLUTION
VALUES ('S169', 'P146804', 'IFMIS', 'Integrated Financial Management Information System',
        'http://documents.worldbank.org/curated/en/2011/05/16215662/mauritania-public-expenditure-review-update',
        'LDSW', '2018');
INSERT INTO FMIS_SOLUTION
VALUES ('S171', 'P150827', 'SIGFIP', 'Système Intégré de Gestion des Finances Publiques',
        'http://www.sndi.ci/index.php/component/content/article/35-infosndi/78-sigfip.html', 'LDSW > Oracle', '2018');
INSERT INTO FMIS_SOLUTION
VALUES ('S173', 'P133424', 'IFMIS', 'Integrated Financial Management Information System',
        'http://mofed.gov.sl/pfmru1.htm#placeholder', 'Web (FreeBalance);', '2018');
INSERT INTO FMIS_SOLUTION
VALUES ('S175', 'P122998', 'FTAS / eBudget', 'Federal Treasury Automation System', 'http://www1.minfin.ru/ru/ebudget',
        'Web (Oracle > customized);', '2017');
INSERT INTO FMIS_SOLUTION
VALUES ('S177', 'P147343', 'IFMIS', 'Integrated Financial Management Information System',
        'http://www.mofnp.gov.zm/index.php?option=com_content&task=view&id=121&Itemid=130', 'Web (SAP);', '2017');
INSERT INTO FMIS_SOLUTION
VALUES ('S179', 'P130878', 'IFMIS', 'Integrated Financial Management Information System',
        'http://www.eastafritac.org/images/uploads/documents_storage/Theme_A-IFMIS_managing_risks.pdf',
        'CS (Epicor 7.3.5);', '2016');
INSERT INTO FMIS_SOLUTION
VALUES ('S181', 'P146006', 'SFMIS', 'Somalia Financial Management Information System',
        'http://www.afdb.org/fileadmin/uploads/afdb/Documents/Project-and-Operations/SOMALIA%20-%20Country%20Brief.pdf',
        'CS (LDSW);', '2016');
INSERT INTO FMIS_SOLUTION
VALUES ('S183', 'P151492', 'SFMIS', 'Somalia Financial Management Information System',
        'http://www.afdb.org/fileadmin/uploads/afdb/Documents/Project-and-Operations/SOMALIA%20-%20Country%20Brief.pdf',
        'CS (LDSW);', '2016');
INSERT INTO FMIS_SOLUTION
VALUES ('S185', 'P090265', 'CID', 'Circuit Informatisé de la Dépense / Integrated Expenditure System',
        'http://www-wds.worldbank.org/external/default/WDSContentServer/WDSP/IB/2007/09/19/000020439_20070919084700/Rendered/PDF/32710.pdf',
        'CS (Oracle);', '2016');
INSERT INTO FMIS_SOLUTION
VALUES ('S187', 'P129332', 'AFMIS', 'Albania Financial Management Information System',
        'http://www.minfin.gov.al/minfin/Sistemi_AMoFTS_1377_1.php', 'LDSW', '2016');
INSERT INTO FMIS_SOLUTION
VALUES ('S189', 'P107355', 'ASTER/SIGFIP',
        'Application des Services du Trésor en Réseau / Système Intégré de Gestion des Finances Publiques',
        'http://www.sndi.ci/index.php/component/content/article/35-infosndi/78-sigfip.html', 'LDSW', '2016');
INSERT INTO FMIS_SOLUTION
VALUES ('S191', 'P104041', 'FMIS', 'Financial Management Information System',
        'http://www.pefa.org/en/assessment/drc-mar08-pfmpr-public-en', 'MS Navision', '2016');
INSERT INTO FMIS_SOLUTION
VALUES ('S193', 'P145747', 'FMIS', 'Financial Management Information System',
        'http://www.pefa.org/en/assessment/drc-mar08-pfmpr-public-en', 'MS Navision', '2016');
INSERT INTO FMIS_SOLUTION
VALUES ('S195', 'P090389', 'PFMS', 'Public Financial Management System',
        'http://www.minfin.gov.ua/control/uk/publish/article?art_id=283476&cat_id=283464', NULL, '2016');
INSERT INTO FMIS_SOLUTION
VALUES ('S197', 'P097026', 'GIFMIS', 'Government Integrated Financial Management Information System',
        'http://www.gifmis.gov.ng/gif-mis/index.php?option=com_content&view=article&id=2&Itemid=2', 'Web (COTS);',
        '2016');
INSERT INTO FMIS_SOLUTION
VALUES ('S199', 'P127319', 'IFMIS', 'Integrated Financial Management Information System',
        'http://www.mof.gov.lr/content.php?sub=98&related=33&res=98&third=98', 'Web (FreeBalance);', '2016');
INSERT INTO FMIS_SOLUTION
VALUES ('S201', 'P110050', 'SIAFI', 'Sistema de Administración Financiera Integrada',
        'http://www.sefin.gob.hn/?page_id=17', 'Web (LDSW, Oracle);', '2016');
INSERT INTO FMIS_SOLUTION
VALUES ('S203', 'P143774', 'FMIS', 'Financial Management Information System',
        'http://fmis.mef.gov.kh/contents/uploads/2014/05/FMIS-Newsletter-001-English.pdf', 'Web (People Soft, Oracle);',
        '2016');
INSERT INTO FMIS_SOLUTION
VALUES ('S205', 'P145317', 'PAS', 'Public Accounting System',
        'http://www.finance.gov.mv/v1/orgview?unit=Information%20Communication%20Technology%20Section', 'Web (SAP);',
        '2016');
INSERT INTO FMIS_SOLUTION
VALUES ('S207', 'P121492', 'FMIS', 'Financial Management Information System',
        'http://www.mef.gob.pa/es/servicios/Paginas/versionesdelsiafpa.aspx', 'Web (SAP);', '2016');
INSERT INTO FMIS_SOLUTION
VALUES ('S209', 'P102376', 'SIGFIP', 'Système Intégré de Gestion des Finances Publiques',
        'http://siteresources.worldbank.org/INTDEBTDEPT/PreliminaryDocuments/22539668/ComorosPD.pdf', 'Web (SIM-BA);',
        '2016');
INSERT INTO FMIS_SOLUTION
VALUES ('S211', 'P122476', 'SIGFIP', 'Système Intégré de Gestion des Finances Publiques',
        'http://www.tresor.gouv.sn/index.php?option=com_content&view=article&id=198&Itemid=202', 'CS (ASTER+SIGFIP);',
        '2015');
INSERT INTO FMIS_SOLUTION
VALUES ('S213', 'P095314', 'SAFI II', 'Sistema de Administración Financiera Integrado',
        'http://www.mh.gob.sv/portal/page/portal/PMH/Novedades/Calendario/Capacitaciones:Capacitaciones_2012:safi2012',
        'LDSW > Informix', '2015');
INSERT INTO FMIS_SOLUTION
VALUES ('S215', 'P125770', 'CTS', 'Core Treasury System', 'http://lmbis.gov.np/', 'LDSW > Oracle', '2015');
INSERT INTO FMIS_SOLUTION
VALUES ('S217', 'P108253', 'FMIS > CEGIB', 'Comptabilité de l’Etat et Gestion intégrée du Budget',
        'http://www.pefa.org/en/assessment/ne-mar13-pfmpr-public-en', 'LDSW > Oracle', '2015');
INSERT INTO FMIS_SOLUTION
VALUES ('S219', 'P121455', 'GIFMIS', 'Government Integrated Financial Management Information System',
        'http://www.gifmis.gov.ng/gif-mis/index.php?option=com_content&view=article&id=2&Itemid=2', 'Web (COTS);',
        '2015');
INSERT INTO FMIS_SOLUTION
VALUES ('S221', 'P133045', 'SIFMIS', 'State Integrated Financial Management Information System',
        'http://www.gifmis.gov.ng/gif-mis/index.php?option=com_content&view=article&id=2&Itemid=2', 'Web (COTS);',
        '2015');
INSERT INTO FMIS_SOLUTION
VALUES ('S223', 'P163540', 'GIFMIS', 'Government Integrated Financial Management Information System',
        'http://www.gifmis.gov.ng/gif-mis/index.php?option=com_content&view=article&id=2&Itemid=2', 'Web (COTS);',
        '2015');
INSERT INTO FMIS_SOLUTION
VALUES ('S225', 'P117363', 'AFMIS', 'Automated Financial Management Information System',
        'http://www.pfmpyemen.org/index.php/management-information-systems/afmis', 'Web (LDSW, Oracle);', '2015');
INSERT INTO FMIS_SOLUTION
VALUES ('S227', 'P099840', 'TFMIS', 'Tajikistan Financial Management Information System',
        'http://minfin.tj/reform.html', 'Web (LDSW);', '2015');
INSERT INTO FMIS_SOLUTION
VALUES ('S229', 'P085133', 'SPAN', 'Sistem Perbendaharaan dan Anggaran Negara / State Treasury and Budgetary System',
        'http://www.span.depkeu.go.id', 'Web (Oracle);', '2015');
INSERT INTO FMIS_SOLUTION
VALUES ('S231', 'P150922', 'IFMIS + IBEX', 'IFMIS & Integrated Budget and Expenditure System (IBEX);',
        'http://www.tctsys.com/project_portfolio.html', 'Web (Oracle);', '2015');
INSERT INTO FMIS_SOLUTION
VALUES ('S233', 'P120427', 'AFMIS', 'Afghanistan Financial Management Information System',
        'http://mof.gov.af/en/page/1149', 'CS (FreeBalance);', '2014');
INSERT INTO FMIS_SOLUTION
VALUES ('S235', 'P117248', 'iBAS', 'Integrated Budget and Accounting System',
        'http://www.mof.gov.bd/en/budget/11_12/digital_bd/digital_bangladesh_en.pdf', 'LDSW', '2014');
INSERT INTO FMIS_SOLUTION
VALUES ('S237', 'P150381', 'FMIS', 'Financial Management Information System', 'http://minfin.tj/reform.html', NULL,
        '2014');
INSERT INTO FMIS_SOLUTION
VALUES ('S239', 'P087945', 'FMIS', 'Financial Management Information System',
        'http://fmis.mef.gov.kh/contents/uploads/2014/05/FMIS-Newsletter-001-English.pdf', 'People Soft, Oracle',
        '2014');
INSERT INTO FMIS_SOLUTION
VALUES ('S241', 'P111795', 'SIGAF', 'Sistema de Información para la Gestión Administrativa y Financiera',
        'http://www.hacienda.gob.ni/Direcciones/tecnologia/hacienda/Direcciones/tecnologia/aplicaciones',
        'Web (FreeBalance);', '2014');
INSERT INTO FMIS_SOLUTION
VALUES ('S243', 'P092484', 'FMIS', 'Financial Management Information System',
        'http://www.mof.gov.tl/about-the-ministry/organisation-structure-roles-and-people/general-directorate-of-state-finances/treasury-directorate/financial-reporting/?lang=en',
        'Web (FreeBalance);', '2014');
INSERT INTO FMIS_SOLUTION
VALUES ('S245', 'P106628', 'SIIF', 'Sistema Integrado de Información Financiera',
        'http://www.minhacienda.gov.co/HomeMinhacienda/siif', 'Web (LDSW, MSSQL?);', '2014');
INSERT INTO FMIS_SOLUTION
VALUES ('S247', 'P103950', 'SIIGFP', 'Système Intégré Informatisé de Gestion des Finances Publiques',
        'http://siigfp.mfb.gov.mg:9717/dgb-sigfp-client/#/login', 'Web (LDSW, Oracle);', '2014');
INSERT INTO FMIS_SOLUTION
VALUES ('S249', 'P093610', 'GIFMIS', 'Government Integrated Financial Management Information System',
        'http://www.cagd.gov.gh/gifmis/index.php?option=com_content&view=article&id=28&Itemid=2&showall=1',
        'Web (Oracle);', '2014');
INSERT INTO FMIS_SOLUTION
VALUES ('S251', 'P151447', 'GIFMIS', 'Government Integrated Financial Management Information System',
        'http://www.cagd.gov.gh/gifmis/index.php?option=com_content&view=article&id=28&Itemid=2&showall=1',
        'Web (Oracle);', '2014');
INSERT INTO FMIS_SOLUTION
VALUES ('S253', 'P100635', NULL, NULL, NULL, 'Web (SmartStream);', '2014');
INSERT INTO FMIS_SOLUTION
VALUES ('S255', 'P088150', 'GIFMIS', 'Government Integrated Financial Management Information System',
        'http://www.gifmis.gov.ng/gif-mis/index.php?option=com_content&view=article&id=2&Itemid=2',
        'HP ctr signed in 2011', '2013');
INSERT INTO FMIS_SOLUTION
VALUES ('S257', 'P117275', 'IFMIS', 'Integrated Financial Management Information System',
        'http://www.mofea.gov.gm/index.php?option=com_content&view=article&id=10&Itemid=13', 'Web (Epicor v9);',
        '2013');
INSERT INTO FMIS_SOLUTION
VALUES ('S259', 'P108069', 'IFMIS', 'Integrated Financial Management Information System',
        'http://mofed.gov.sl/pfmru1.htm#placeholder', 'Web (FreeBalance);', '2013');
INSERT INTO FMIS_SOLUTION
VALUES ('S261', 'P071063', 'TMIS', 'Treasury Management Information System',
        'http://www.kazna.gov.kg/index.php/modernizatsiya/isuk', 'Web (FreeBalance);', '2013');
INSERT INTO FMIS_SOLUTION
VALUES ('S263', 'P077778', 'GFMIS', 'Government Financial Management Information System',
        'http://www.mof.gov.mn/category/budget-development/budget-software/', 'Web (FreeBalance);', '2013');
INSERT INTO FMIS_SOLUTION
VALUES ('S265', 'P103441', 'SIGFE II', 'Sistema de Información para la Gestión Financiera del Estado',
        'http://sigfe.sigfe.cl', 'Web (LDSW, Oracle);', '2013');
INSERT INTO FMIS_SOLUTION
VALUES ('S267', 'P082916', 'FMIS (B);', 'Financial Management Information System',
        'http://www.mf.gov.md/about/delur/management', 'Web (LDSW); - Only BPS', '2013');
INSERT INTO FMIS_SOLUTION
VALUES ('S269', 'P075399', 'TABMIS', 'Treasury and Budget Management Information System',
        'http://www.mof.gov.vn/portal/page/portal/mof_en/dn?pers_id=2420195&item_id=43684804&p_details=1',
        'Web (Oracle);', '2013');
INSERT INTO FMIS_SOLUTION
VALUES ('S271', 'P076872', 'FABS', 'Financial Accounting & Budgeting System', 'http://www.pifra.gov.pk', 'Web (SAP);',
        '2013');
INSERT INTO FMIS_SOLUTION
VALUES ('S273', 'P078627', 'SIGEFI',
        'Système Intégré de Gestion des Finances / Integrated Public Financial Management System',
        'http://www.page.bi/spip.php?article35', 'LDSW > MS SQL', '2012');
INSERT INTO FMIS_SOLUTION
VALUES ('S275', 'P070544', 'IFMS', 'Integrated Financial Management System',
        'http://www.mof.go.tz/mofdocs/msemaji/PFMRP%20ANNUAL%20PROGRESS%20REPORT-WEBSITE.pdf', 'WEB (Epicor);', '2012');
INSERT INTO FMIS_SOLUTION
VALUES ('S277', 'P109775', 'IFMIS', 'Integrated Financial Management Information System',
        'http://www.mof.gov.lr/content.php?sub=98&related=33&res=98&third=98', 'Web (FreeBalance);', '2012');
INSERT INTO FMIS_SOLUTION
VALUES ('S279', 'P074447', 'GIFMIS', 'Government Integrated Financial Management Information System',
        'http://www.gifmis.gov.ng/gif-mis/index.php?option=com_content&view=article&id=2&Itemid=2',
        'Web (MS Navision+ Oracle);', '2012');
INSERT INTO FMIS_SOLUTION
VALUES ('S281', 'P082452', 'IFMIS', 'Integrated Financial Management Information System',
        'http://www.mofnp.gov.zm/index.php?option=com_content&task=view&id=121&Itemid=130', 'Web (SAP);', '2012');
INSERT INTO FMIS_SOLUTION
VALUES ('S283', 'P099980', 'AFMIS', 'Afghanistan Financial Management Information System',
        'http://mof.gov.af/en/page/1149', 'CS (FreeBalance);', '2011');
INSERT INTO FMIS_SOLUTION
VALUES ('S285', 'P066386', 'SmartFMS', 'Integrated Financial Management Information System',
        'http://www.minecofin.gov.rw/webfm_send/2098', 'LDSW > Oracle', '2011');
INSERT INTO FMIS_SOLUTION
VALUES ('S287', 'P149095', 'SmartFMS', 'Integrated Financial Management Information System',
        'http://www.minecofin.gov.rw/webfm_send/2098', 'LDSW > Oracle', '2011');
INSERT INTO FMIS_SOLUTION
VALUES ('S289', 'P164807', 'SmartFMS', 'Integrated Financial Management Information System',
        'http://www.minecofin.gov.rw/webfm_send/2098', 'LDSW > Oracle', '2011');
INSERT INTO FMIS_SOLUTION
VALUES ('S291', 'P077620', 'GFIS', 'Government Financial Information System',
        'http://www-wds.worldbank.org/external/default/WDSContentServer/WDSP/IB/2012/03/22/000333038_20120322225943/Rendered/PDF/673470PJPR0v100edbyTACT0CTRNL0LEGES.pdf',
        'Web (LDSW, Oracle);', '2011');
INSERT INTO FMIS_SOLUTION
VALUES ('S293', 'P066175', 'SIAF', 'Sistema Integrado de Administración Financiera',
        'http://www.minfin.gob.gt/frame.php?url=https://sicoin.minfin.gob.gt/sicoinweb/login/frmlogin.htm',
        'Web (LDSW, Oracle);', '2011');
INSERT INTO FMIS_SOLUTION
VALUES ('S295', 'P064508', 'FTAS / eBudget', 'Federal Treasury Automation System', 'http://www1.minfin.ru/ru/ebudget',
        'Web (Oracle > customized);', '2011');
INSERT INTO FMIS_SOLUTION
VALUES ('S297', 'P090567', 'IFMIS', 'Integrated Financial Management Information System', 'http://www.ifmis.go.ke',
        'Web (Oracle);', '2011');
INSERT INTO FMIS_SOLUTION
VALUES ('S299', 'P074448', 'SIIGFP', 'Système Intégré Informatisé de Gestion des Finances Publiques',
        'http://siigfp.mfb.gov.mg:9717/dgb-sigfp-client/#/login', 'Web (LDSW, Oracle);', '2010');
INSERT INTO FMIS_SOLUTION
VALUES ('S301', 'P105143', 'AGFIS', 'Albania Ministry of Finance Treasury System',
        'http://www.minfin.gov.al/minfin/Sistemi_AMoFTS_1377_1.php', 'Web (Oracle);', '2010');
INSERT INTO FMIS_SOLUTION
VALUES ('S303', 'P094193', 'PAS', 'Public Accounting System',
        'http://www.finance.gov.mv/v1/orgview?unit=Information%20Communication%20Technology%20Section', 'Web (SAP);',
        '2010');
INSERT INTO FMIS_SOLUTION
VALUES ('S305', 'P084736', 'AFMIS', 'Afghanistan Financial Management Information System',
        'http://mof.gov.af/en/page/1149', 'CS (FreeBalance);', '2009');
INSERT INTO FMIS_SOLUTION
VALUES ('S307', 'P078891', 'SIGFA', 'Sistema Integrado de Gestión Financiera',
        'http://www.hacienda.gob.ni/Direcciones/tecnologia/hacienda/Direcciones/tecnologia/aplicaciones',
        'CS (LDSW, Oracle);', '2009');
INSERT INTO FMIS_SOLUTION
VALUES ('S309', 'P040109', 'SIIF', 'Sistema Integrado de Información Financiera',
        'http://www.minhacienda.gov.co/HomeMinhacienda/siif', 'CS/Web (LDSW, MSSQL);', '2009');
INSERT INTO FMIS_SOLUTION
VALUES ('S311', 'P078613', 'IFMIS', 'Integrated Financial Management Information System',
        'http://mofed.gov.sl/pfmru1.htm#placeholder', 'Web (FreeBalance);', '2009');
INSERT INTO FMIS_SOLUTION
VALUES ('S313', 'P078408', 'IFMIS', 'Integrated Financial Management Information System',
        'http://www.eastafritac.org/images/uploads/documents_storage/Theme_A-IFMIS_managing_risks.pdf',
        'CS (CODA > Epicor);', '2008');
INSERT INTO FMIS_SOLUTION
VALUES ('S315', 'P074218', 'SIGEF', 'Sistema Integrado de Gestion Financiera',
        'http://integrador.finanzas.gob.ec/sigefWebConsulta2011/Jsp/LoginPage.jsp;jsessionid=1FFD43DE0BF758EB3ADD163C29CE3C52',
        'Web (e-SIGEF, Oracle);', '2008');
INSERT INTO FMIS_SOLUTION
VALUES ('S317', 'P050706', 'AFMIS', 'Automated Financial Management Information System',
        'http://www.pfmpyemen.org/index.php/management-information-systems/afmis', 'Web (LDSW, Oracle);', '2008');
INSERT INTO FMIS_SOLUTION
VALUES ('S319', 'P152932', 'PFMS', 'Public Financial Management System',
        'http://www.iiste.org/Journals/index.php/RJFA/article/view/4973/5056', 'Web (SAP);', '2008');
INSERT INTO FMIS_SOLUTION
VALUES ('S321', 'P057995', 'IFMIS', 'Integrated Financial Management Information System',
        'http://www.mofea.gov.gm/index.php?option=com_content&view=article&id=10&Itemid=13', 'CS (Epicor);', '2007');
INSERT INTO FMIS_SOLUTION
VALUES ('S323', 'P069259', 'SIGFE II', 'Sistema de Información para la Gestión Financiera del Estado',
        'http://sigfe.sigfe.cl', 'Web (LDSW, MS+Ora);', '2007');
INSERT INTO FMIS_SOLUTION
VALUES ('S325', 'P007164', 'SAFI', 'Sistema de Administración Financiera Integrado',
        'http://www.mh.gob.sv/portal/page/portal/PMH/Novedades/Calendario/Capacitaciones:Capacitaciones_2012:safi2012',
        'Web (LDSW, Oracle);', '2007');
INSERT INTO FMIS_SOLUTION
VALUES ('S327', 'P069939', 'AMoFTS', 'Albania Ministry of Finance Treasury System',
        'http://www.minfin.gov.al/minfin/Sistemi_AMoFTS_1377_1.php', 'Web (Oracle);', '2007');
INSERT INTO FMIS_SOLUTION
VALUES ('S329', 'P069864', 'FMIS', 'Financial Management Information System',
        'http://www.pokladnica.sk/sk/informacny-system-sp', 'Web (SAP);', '2007');
INSERT INTO FMIS_SOLUTION
VALUES ('S331', 'P082610', 'AFMIS', 'Afghanistan Financial Management Information System',
        'http://mof.gov.af/en/page/1149', 'CS (FreeBalance);', '2006');
INSERT INTO FMIS_SOLUTION
VALUES ('S333', 'P037049', 'SIDIF', 'Sistema Integrado de Información Financiera',
        'http://administracionfinanciera.mecon.gov.ar', 'CS (LDSW, Oracle);', '2006');
INSERT INTO FMIS_SOLUTION
VALUES ('S335', 'P057601', 'SIGECOF',
        'Sistema Integrado de Gestión y Control de las Finanzas Públicas / Integrated Administration and Control of Public Finance',
        'http://www.oncop.gob.ve/vista/boton.php?var=sigecofx', 'CS (LDSW, Oracle);', '2006');
INSERT INTO FMIS_SOLUTION
VALUES ('S337', 'P044679', 'IFMS', 'Integrated Financial Management System',
        'http://www.finance.go.ug/index.php/ifms.html', 'CS (Oracle);', '2006');
INSERT INTO FMIS_SOLUTION
VALUES ('S339', 'P101614', 'FMIS', 'Financial Management Information System',
        'http://www.kryeministri-ks.net/?page=2,231', 'FreeBalance', '2006');
INSERT INTO FMIS_SOLUTION
VALUES ('S341', 'P060785', 'SIAFI', 'Sistema de Administración Financiera Integrada',
        'http://www.sefin.gob.hn/?page_id=17', 'Web (LDSW, Oracle);', '2006');
INSERT INTO FMIS_SOLUTION
VALUES ('S343', 'P066100', 'TMIS', 'Treasury Information Management System', 'http://www.maliyye.gov.az/en/node/886',
        'Web (SAP);', '2006');
INSERT INTO FMIS_SOLUTION
VALUES ('S345', 'P045588', 'GIFMIS', 'Government Integrated Financial Management Information System',
        'http://www.cagd.gov.gh/gifmis/index.php?option=com_content&view=article&id=28&Itemid=2&showall=1',
        'CS (Oracle);', '2005');
INSERT INTO FMIS_SOLUTION
VALUES ('S347', 'P051855', 'GFMIS', 'Government Financial Management Information System',
        'http://www.mof.gov.mn/category/budget-development/budget-software/', 'Web (FreeBalance);', '2005');
INSERT INTO FMIS_SOLUTION
VALUES ('S349', 'P077417', 'AFMIS', 'Afghanistan Financial Management Information System',
        'http://mof.gov.af/en/page/1149', 'CS (FreeBalance);', '2004');
INSERT INTO FMIS_SOLUTION
VALUES ('S351', 'P066490', 'IFMIS', 'Integrated Financial Management Information System', 'http://www.ifmis.go.ke',
        'CS (Oracle);', '2004');
INSERT INTO FMIS_SOLUTION
VALUES ('S353', 'P036015', 'FABS', 'Financial Accounting & Budgeting System', 'http://www.pifra.gov.pk',
        'CS (SAP); Distributed', '2004');
INSERT INTO FMIS_SOLUTION
VALUES ('S355', 'P049174', 'PFMS', 'Public Financial Management System',
        'http://www.minfin.gov.ua/control/uk/publish/article?art_id=283476&cat_id=283464', 'Web (LDSW: Ora+MS);',
        '2004');
INSERT INTO FMIS_SOLUTION
VALUES ('S357', 'P174822', 'FMIS > CEGIB', 'Comptabilité de l’Etat et Gestion intégrée du Budget',
        'http://www.pefa.org/en/assessment/ne-mar13-pfmpr-public-en', 'LDSW > Oracle', '2003');
INSERT INTO FMIS_SOLUTION
VALUES ('S359', 'P040110', 'SIGMA', 'Sistema Integrado de Gestión y Modernización Administrativa',
        'http://www.sigma.gob.bo/php/index.php', 'Web (LDSW, Oracle 6i);', '2003');
INSERT INTO FMIS_SOLUTION
VALUES ('S361', 'P001657', 'IFMIS', 'Integrated Financial Management Information System',
        'http://www.eastafritac.org/images/uploads/documents_storage/Theme_A-IFMIS_managing_risks.pdf',
        'CS (CODA Financials);', '2002');
INSERT INTO FMIS_SOLUTION
VALUES ('S363', 'P007490', 'FMIS', 'Financial Management Information System',
        'http://www.fsl.org.jm/systems/financial-management-information-system', 'CS (LDSW, Informix);', '2002');
INSERT INTO FMIS_SOLUTION
VALUES ('S365', 'P049296', 'SIGFA', 'Sistema Integrado de Gestión Financiera',
        'http://www.hacienda.gob.ni/Direcciones/tecnologia/hacienda/Direcciones/tecnologia/aplicaciones',
        'CS (LDSW, Oracle);', '2002');
INSERT INTO FMIS_SOLUTION
VALUES ('S367', 'P048657', 'SIAF', 'Sistema Integrado de Administración Financiera',
        'http://www.minfin.gob.gt/frame.php?url=https://sicoin.minfin.gob.gt/sicoinweb/login/frmlogin.htm',
        'CS (LDSW, Oracle);', '2002');
INSERT INTO FMIS_SOLUTION
VALUES ('S369', 'P036041', 'GFMIS', 'Government Financial Management Information System',
        'http://www.bjcz.gov.cn/english/Golden%20Finance%20Project.htm', 'CS (LDSW, Sybase);', '2002');
INSERT INTO FMIS_SOLUTION
VALUES ('S371', 'P043446', 'GFMIS', 'Government Financial Management Information System',
        'http://www-wds.worldbank.org/external/default/WDSContentServer/WDSP/IB/2003/03/07/000094946_0301180408511/Rendered/PDF/multi0page.pdf',
        'Web (LDSW: Ora);', '2002');
INSERT INTO FMIS_SOLUTION
VALUES ('S373', 'P037960', 'Treasury', 'Treasury System',
        'http://www-wds.worldbank.org/external/default/WDSContentServer/WDSP/IB/2003/06/27/000112742_20030627113447/Rendered/PDF/257110ICR0.pdf',
        'Web (Oracle);', '2002');
INSERT INTO FMIS_SOLUTION
VALUES ('S375', 'P007136', 'SIGEF', 'Sistema Integrado de Gestion Financiera',
        'http://integrador.finanzas.gob.ec/sigefWebConsulta2011/Jsp/LoginPage.jsp;jsessionid=1FFD43DE0BF758EB3ADD163C29CE3C52',
        'CS (LDSW, Oracle);', '2001');
INSERT INTO FMIS_SOLUTION
VALUES ('S377', 'P035759', 'say2000i / KBS', 'say2000i Public Expenditure Management and Accounting System',
        'https://www.kbs.gov.tr', 'Web (LDSW: say2000i);', '2001');
INSERT INTO FMIS_SOLUTION
VALUES ('S379', 'P004019', 'SPAN', 'Sistem Perbendaharaan dan Anggaran Negara / State Treasury and Budgetary System',
        'http://www.span.depkeu.go.id', 'CS (Oracle);', '2000');
INSERT INTO FMIS_SOLUTION
VALUES ('S381', 'P000301', 'CID', 'Circuit Informatisé de la Dépense / Integrated Expenditure System',
        'http://www.tresor.bf/spip.php?page=articleS&id_article=29', 'CS (Oracle);', '2000');
INSERT INTO FMIS_SOLUTION
VALUES ('S383', 'P006889', 'SIIF', 'Sistema Integrado de Información Financiera',
        'http://www.minhacienda.gov.co/HomeMinhacienda/siif', 'CS/Web (LDSW);', '2000');
INSERT INTO FMIS_SOLUTION
VALUES ('S385', 'P035080', 'SIGFA', 'Sistema Integrado de Gestión Financiera',
        'http://www.hacienda.gob.ni/Direcciones/tecnologia/hacienda/Direcciones/tecnologia/aplicaciones',
        'CS (LDSW, Oracle);', '1999');
INSERT INTO FMIS_SOLUTION
VALUES ('S387', 'P007213', 'SIAF', 'Sistema Integrado de Administración Financiera',
        'http://www.minfin.gob.gt/frame.php?url=https://sicoin.minfin.gob.gt/sicoinweb/login/frmlogin.htm',
        'CS (LDSW, Oracle);', '1999');
INSERT INTO FMIS_SOLUTION
VALUES ('S389', 'P034607', 'SIAFI', 'Sistema de Administración Financiera Integrada',
        'http://www.sefin.gob.hn/?page_id=17', 'CS (LDSW, Oracle);', '1999');
INSERT INTO FMIS_SOLUTION
VALUES ('S391', 'P007457', 'FMIS', 'Financial Management Information System',
        'http://www.fsl.org.jm/systems/financial-management-information-system', 'CS (LDSW, Informix);', '1998');
INSERT INTO FMIS_SOLUTION
VALUES ('S393', 'P006029', 'SIDIF', 'Sistema Integrado de Información Financiera',
        'http://administracionfinanciera.mecon.gov.ar', 'CS (LDSW, Oracle);', '1997');
INSERT INTO FMIS_SOLUTION
VALUES ('S395', 'P006189', 'SIGMA', 'Sistema Integrado de Gestión y Modernización Administrativa',
        'http://www.sigma.gob.bo/php/index.php', 'CS (LDSW, Oracle);', '1997');
INSERT INTO FMIS_SOLUTION
VALUES ('S397', 'P006669', 'SIGFE II', 'Sistema de Información para la Gestión Financiera del Estado',
        'http://sigfe.sigfe.cl', 'CS (LDSW);', '1997');
INSERT INTO FMIS_SOLUTION
VALUES ('S399', 'P006160', 'SIGMA', 'Sistema Integrado de Gestión y Modernización Administrativa',
        'http://www.sigma.gob.bo/php/index.php', 'CS (LDSW, Oracle);', '1992');
INSERT INTO FMIS_SOLUTION
VALUES ('S401', 'P007071', 'SIGEF', 'Sistema Integrado de Gestion Financiera',
        'http://integrador.finanzas.gob.ec/sigefWebConsulta2011/Jsp/LoginPage.jsp;jsessionid=1FFD43DE0BF758EB3ADD163C29CE3C52',
        'Lotus on nw PCs', '1992');
INSERT INTO FMIS_SOLUTION
VALUES ('S403', 'P006394', 'SIAFI', 'Sistema Integrado de Administração Financeira do Governo Federal',
        'https://www.tesouro.fazenda.gov.br/pt/siafi', 'CS/Web (LDSW : SIAFI);', '1987');

---BACKUP
docker exec -it 4f18f8f9dcfa4e83e4388585cc8d2b4a56c12d8419b2d00dea1a4422fcbdd668 /bin/sh
---dang nhap
            su - db2inst1
 db2 list db directory
    db2 connect to DB2
        db2 get db cfg for DB2 | grep LOGARC
            db2 get db cfg for DB2 | grep TRACK
----BACK UP VÀO Ổ

       -- BACKUP RESTORE
                cd /database/data/backup
db2 "BACKUP DATABASE DB2 to "/database/data/backup" COMPRESS "

db2 "DROP DB DB2"
RESTORE DB DB2;

----- RESTORE INTO ANOTHER DB
RESTORE DATABASE DB2 TAKEN AT 20230626055826 INTO NEWDB WITHOUT ROLLING FORWARD WITHOUT PROMPTING;


---
    db2 "DEACTIVATE DB DB2"

---
        db2 "FORCE APPLICATION ALL"

        db2 rollforward db DB2 to end of logs and stop

            ---được sử dụng để thực hiện phục hồi cơ sở dữ liệu DB2 từ điểm cuối của log và sau đó dừng quá trình phục hồi. Điểm cuối của log là thời điểm gần nhất trong log mà cơ sở dữ liệu đã được sao lưu.


----backup online
            db2 "TERMINATE"
            db2 "FORCE APPLICATION ALL"
            db2 "UPDATE DB CFG FOR DB2 USING TRACKMODE ON"
            db2 "ACTIVATE DB DB2"
            db2 "BACKUP DATABASE DB2 ONLINE INCREMENTAL to "/database/data/backup" COMPRESS  INCLUDE LOGS" > backup.log




