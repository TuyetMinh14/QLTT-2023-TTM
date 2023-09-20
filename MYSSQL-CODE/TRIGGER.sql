---check status -------->PASSED
CREATE TRIGGER CHECK_PSTATUS ON PROJECTS
AFTER INSERT, UPDATE
AS
BEGIN
    IF EXISTS (
        SELECT Project_Status
        FROM INSERTED
        WHERE Project_Status NOT IN ('A', 'P', 'C')
    )
    BEGIN
        THROW 50000, 'INVALID STATUS', 1;
        RETURN;
    END
END

INSERT INTO PROJECTS VALUES('P0','Public Service Capacity Building Project','K','Zambia')
SELECT * FROM PROJECTS WHERE Project_id = 'P0'

UPDATE PROJECTS SET Project_Status = 'k' WHERE Project_id = 'P000301'
SELECT * FROM PROJECTS WHERE Project_id = 'P000301'
DROP TRIGGER CHECK_PSTATUS



------check time line ---------->PASSED
GO
CREATE TRIGGER Check_Timeline ON TIMELINE 
AFTER INSERT,UPDATE
AS
BEGIN
    DECLARE @ERROR VARCHAR(30)
    SET @ERROR = 'TIMELINE IS NOT APPROVAL'
    IF EXISTS (SELECT *
    FROM INSERTED
    WHERE Concept_Review > Appraisal OR Appraisal > Approval OR Approval > Effective_Actual OR Approval > Effective_Actual
        OR Effective_Actual > MidTerm_Review OR MidTerm_Review > Closing OR Closing > Closing_Actual  )
    BEGIN
        RAISERROR(@ERROR,15,1)
        ROLLBACK TRANSACTION
        RETURN
    END
END

UPDATE TIMELINE SET Closing_Actual = '10/10/2022' where Project_id = 'P084160'
---------------

----UPDATE TOTYEARS KHI CÓ THAY ĐỔI VỀ CLOSING VÀ CONCEPT REVIEW
GO
CREATE TRIGGER UPDATE_TOT_YRS ON TIMELINE
AFTER UPDATE, INSERT
AS 
BEGIN
    UPDATE TIMELINE
    SET Tot_yrs = DATEDIFF(DAY, T.Concept_Review, T.Closing_Actual) / 365.0
    FROM TIMELINE T
    INNER JOIN inserted I ON T.Project_id = I.Project_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM deleted D
        WHERE D.Project_id = T.Project_id
    )
END
DROP TRIGGER [dbo].[UPDATE_TOT_YRS]

UPDATE TIMELINE SET Closing_Actual = '10/10/2016' where Project_id = 'P084160'

SELECT *
FROM TIMELINE
WHERE  Project_id = 'P084160'

----------CAP NHAT BBPERYRS
GO
CREATE TRIGGER UPDATE_BB_PER_YRS_ON_COST ON COST
AFTER UPDATE, INSERT
AS
BEGIN
    DECLARE @Project_id CHAR(7)
    SET @Project_id = (SELECT Project_id
    from INSERTED )
    UPDATE COST SET Avg_BBbyyr = (SELECT BB
    FROM INSERTED)/(SELECT Tot_Yrs
    FROM TIMELINE
    WHERE TIMELINE.Project_id = @Project_id )
        WHERE COST.Project_id = @Project_id
END

GO
CREATE TRIGGER UPDATE_BB_PER_YRS_ON_TL ON TIMELINE
AFTER UPDATE, INSERT
AS
BEGIN
     UPDATE COST
    SET Avg_BBbyyr = C.BB / T.Tot_Yrs
    FROM COST C
    INNER JOIN TIMELINE T ON C.Project_id = T.Project_id
    INNER JOIN inserted I ON T.Project_id = I.Project_id
    WHERE NOT EXISTS (
        SELECT 1
        FROM deleted D
        WHERE D.Project_id = T.Project_id
    )
END

DROP TRIGGER [dbo].[UPDATE_BB_PER_YRS_ON_TL]

SELECT *
FROM COST
WHERE  Project_id = 'P048657'

SELECT *
FROM TIMELINE
WHERE  Project_id = 'P048657'

UPDATE COST SET BB = 40000 where Project_id = 'P048657'
UPDATE TIMELINE SET Closing_Actual = '9/30/2002' where Project_id = 'P048657'



----UPDATE TOTAL PROJECTS 
GO
CREATE TRIGGER TOTAL_PROJECTS ON PROJECTS
AFTER INSERT
AS 
BEGIN

    UPDATE COUNTRIES SET total_projects   = (SELECT COUNT(PROJECTS.Project_id) FROM PROJECTS INNER JOIN INSERTED ON PROJECTS.Country = INSERTED.Country)
    FROM [dbo].[COUNTRIES] C
        INNER JOIN inserted I ON C.Country_name = I.Country;

END

DROP TRIGGER TOTAL_PROJECTS
INSERT INTO PROJECTS
VALUES('P1', 'Public Institutional Development Project', 'C', 'Burkina Faso')
delete from PROJECTS where Project_id = 'P1'
SELECT *
FROM COUNTRIES
WHERE Country_name= 'Burkina Faso'

GO
CREATE TRIGGER UPDATE_TOTALPROJECTS ON PROJECTS
AFTER UPDATE 
AS BEGIN
    UPDATE C
    SET total_projects = total_projects - 1
    FROM [dbo].[COUNTRIES] C
        INNER JOIN deleted D ON C.Country_name = D.Country;

    UPDATE COUNTRIES
    SET total_projects = total_projects + 1
    FROM [dbo].[COUNTRIES] C
        INNER JOIN inserted I ON C.Country_name = I.Country
END

    UPDATE COUNTRIES SET Country_name = 'Burkina Faso'


GO
CREATE TRIGGER DELETE_PROJECT ON PROJECTS
AFTER delete
AS BEGIN
    UPDATE C
    SET total_projects = total_projects - 1
    FROM [dbo].[COUNTRIES] C
        INNER JOIN deleted D ON C.Country_name = D.Country;
END


----------TRIGGER TÍNH TỔNG DỰ ÁN TRONG REGION 
---SAU KHI INSERT
GO
CREATE TRIGGER trg_UpdateTotalProjects
ON COUNTRIES
AFTER UPDATE
AS
BEGIN
    -- Update the total_projects column in REGIONS table
    UPDATE R
    SET [total_projects] = (
        SELECT SUM(total_projects)
        FROM [dbo].[COUNTRIES]
        WHERE Region_id = R.Regions_id
    )
    FROM [dbo].[REGIONS] R
    INNER JOIN inserted I ON R.Regions_id = I.Region_id;
END;

------------XOÁ DỰ ÁN 
GO
CREATE TRIGGER DELETE_PROJECT_ONDATABASE ON PROJECTS 
AFTER DELETE 
AS 
BEGIN
    IF NOT EXISTS (SELECT * FROM PROJECTS)
        BEGIN
    PRINT 'THERE IS NO PROJECTS'
        END
    ELSE
        BEGIN

    DELETE FROM TIMELINE WHERE Project_id = (SELECT Project_id FROM DELETED)
    DELETE FROM COST WHERE Project_id = (SELECT Project_id FROM DELETED)
    DELETE FROM FMIS_SOLUTION WHERE Project_id = (SELECT Project_id FROM DELETED)

    END
END

    ALTER TABLE TIMELINE NOCHECK CONSTRAINT ALL
    ALTER TABLE COST NOCHECK CONSTRAINT ALL
    ALTER TABLE FMIS_SOLUTION NOCHECK CONSTRAINT ALL
    ALTER TABLE PROJECTS NOCHECK CONSTRAINT ALL



delete from PROJECTS where Project_id = 'P143197'
select * from PROJECTS WHERE Project_id = 'P143197'

DROP TRIGGER DELETE_PROJECT_ONDATABASE

ALTER TABLE TIMELINE CHECK CONSTRAINT ALL
    ALTER TABLE COST CHECK CONSTRAINT ALL
    ALTER TABLE FMIS_SOLUTION CHECK CONSTRAINT ALL
    ALTER TABLE PROJECTS CHECK CONSTRAINT ALL




































---------
GO
BEGIN
    DECLARE @DUYET CURSOR, @Project_id char(8), @Tot_yrs float
    SET @DUYET = CURSOR FOR SELECT Project_id
    FROM TIMELINE
    OPEN @DUYET
    FETCH NEXT FROM @DUYET INTO @Project_id
    WHILE @@FETCH_STATUS = 0
Begin
        SET @Tot_yrs = (SELECT CAST(DATEDIFF(DAY,Concept_Review,Closing_Actual) As float)/365
        from TIMELINE
        WHERE TIMELINE.Project_id = @Project_id  )
        update TIMELINE SET Tot_Yrs = @Tot_yrs where TIMELINE.Project_id = @Project_id
        FETCH NEXT FROM @DUYET INTO @Project_id
    END
END
CLOSE @DUYET
DEALLOCATE @DUYET
END


-----
go
BEGIN
    DECLARE @COST CURSOR, @Project_id char(8), @AVG_BBbyyr float
    SET @COST = CURSOR FOR SELECT Project_id
    FROM COST
    OPEN @COST
    FETCH NEXT FROM @COST INTO @Project_id
    WHILE @@FETCH_STATUS = 0
Begin
        SET @AVG_BBbyyr = (SELECT BB
        FROM COST
        WHERE COST.Project_id = @Project_id)/(SELECT Tot_Yrs
        FROM TIMELINE
        WHERE TIMELINE.Project_id = @Project_id)
        update COST SET AVG_BBbyyr = @AVG_BBbyyr where COST.Project_id = @Project_id
        FETCH NEXT FROM @COST INTO @Project_id
    END
    CLOSE @COST
END

SELECT *
FROM COST



-------con trỏ tạo fill tổng dự án 
BEGIN
    DECLARE @countries CURSOR, @Countryname char(48), @total int
    SET @countries = CURSOR FOR SELECT Country_name
    FROM COUNTRIES
    OPEN @countries
    FETCH NEXT FROM @countries INTO @Countryname
    WHILE @@FETCH_STATUS = 0
Begin
        SET @total = (SELECT COUNT(Project_id)
        FROM PROJECTS
        WHERE Country = @Countryname )
        update COUNTRIES SET [total_projects ] = @total WHERE Country_name = @Countryname
        FETCH NEXT FROM @countries INTO @Countryname
    END
    CLOSE @countries
END

select *
from COUNTRIES





