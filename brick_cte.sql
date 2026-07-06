-- Databricks-compatible version using CTEs
WITH 
-- CTE for licensing data (Active)
lic AS (
    SELECT 
        CASE WHEN LEFT(TT.uid,2) = '00' THEN CONCAT('00', TT.uid)
             WHEN LEFT(TT.uid,1) = '0' THEN CONCAT('000', TT.uid)
             ELSE TT.uid
        END as uid,
        CASE WHEN ah.AgentCategoryDescription = 'Administrator' THEN 'NASP'
             WHEN (TT.cob>0 and TT.mcob>0 and TT.icob >0) or (TT.cob>0 and TT.mcob>0) THEN 'CMCOB'
             WHEN (TT.cob>0 and TT.icob >0) or TT.cob>0 THEN 'COB'
             WHEN TT.ICOB_GI>0 THEN 'ICOB GI ONLY'
             WHEN (TT.mcob>0 and TT.icob >0) or TT.mcob>0 THEN 'MCOB'
             WHEN TT.ICOB_Owl >0 THEN 'ICOB_Owl'
             ELSE 'ICOB' 
        END as `business area`,
        TT.CF30Status,
        CASE WHEN TT.`Date Achieved` IS NOT NULL THEN TT.`Date Achieved` ELSE NULL END as `COB Competency Date`
    FROM (
        SELECT 
            uid,
            SUM(CASE WHEN (BusinessArea LIKE 'cob%' AND CF30Status <> 'Not Set') THEN 1 ELSE 0 END) as COB,
            SUM(CASE WHEN BusinessArea LIKE 'mcob%' THEN 1 ELSE 0 END) as MCOB,
            SUM(CASE WHEN BusinessArea LIKE 'icob%' AND BusinessArea NOT LIKE '%Owl%' THEN 1 ELSE 0 END) as ICOB,
            SUM(CASE WHEN BusinessArea LIKE 'icob GI%' THEN 1 ELSE 0 END) as ICOB_GI,
            SUM(CASE WHEN BusinessArea LIKE '%Owl%' THEN 1 ELSE 0 END) as ICOB_Owl,
            CF30Status,
            MAX(CASE WHEN (BusinessArea LIKE 'cob%' AND CF30Status <> 'Not Set') THEN 3 ELSE 0 END) as `COB Competency`,
            MAX(CASE WHEN (BusinessArea LIKE 'cob%' AND CF30Status <> 'Not Set') THEN `Date Achieved` ELSE NULL END) as `Date Achieved`
        FROM (
            SELECT DISTINCT 
                CASE WHEN UD.USR_ExternalID = '0072' THEN '1008203' 
                     WHEN UD.USR_ExternalID = '1003604' THEN '1005181' 
                     WHEN UD.USR_ExternalID = '1010321' THEN '1010897'
                     WHEN UD.USR_ExternalID = '1010364' THEN '1010744' 
                     WHEN UD.USR_ExternalID = '4001674' THEN '1011586' 
                     ELSE UD.USR_ExternalID 
                END as UID,
                CD.Code_Description as BusinessArea,
                CD2.Code_Description AS CF30Status,
                UC.UC_Status as Status,
                MAX(UC.UC_CompetencyLevel) as Level,
                UC.UC_BusinessArea,
                CASE WHEN UC.UC_BusinessArea = 3 THEN CAST(UC.UC_DateAchieved AS DATE) ELSE NULL END as `Date Achieved`
            FROM dbo.sa_insight_Licence L 
            INNER JOIN dbo.sa_insight_UserLicence UL ON L.LIC_ID = UL.ULIC_LicenceID 
            RIGHT JOIN dbo.sa_insight_Staff S 
                INNER JOIN dbo.sa_insight_UserDetails UD ON S.STAF_UserID = UD.USR_ID 
                INNER JOIN dbo.sa_insight_UserCompetency UC ON UD.USR_ID = UC.UC_OwnerID 
                ON UL.ULIC_UserID = UD.USR_ID 
            LEFT JOIN dbo.sa_insight_CodeDescription CD ON UC.UC_BusinessArea = CD.Code_Code AND CD.Code_CodeType = 534 
            LEFT JOIN dbo.sa_insight_CodeDescription AS CD2 ON S.STAF_CustomerFunction = CD2.Code_Code AND CD2.Code_CodeType = 530
            WHERE UC_Status <> 1 AND UC.UC_BusinessArea <= 9
            GROUP BY UD.USR_ExternalID, UC.UC_Status, CD.Code_Description, CD2.Code_Description, UC.UC_BusinessArea, UC.UC_DateAchieved
        ) T
        GROUP BY uid, CF30Status
    ) TT
    LEFT JOIN dbo.cscv_AgentsHierarchy ah ON ah.Agentcode = TT.UID
),

-- CTE for leavers licensing data
Leaverslic AS (
    SELECT 
        CASE WHEN LEFT(TTL.uid,2) = '00' THEN CONCAT('00', TTL.uid)
             WHEN LEFT(TTL.uid,1) = '0' THEN CONCAT('000', TTL.uid)
             ELSE TTL.uid
        END as uid,
        CASE WHEN ah.AgentCategoryDescription = 'Administrator' THEN 'NASP'
             WHEN (TTL.cob>0 and TTL.mcob>0 and TTL.icob >0) or (TTL.cob>0 and TTL.mcob>0) THEN 'CMCOB'
             WHEN (TTL.cob>0 and TTL.icob >0) or TTL.cob>0 THEN 'COB'
             WHEN TTL.ICOB_GI>0 THEN 'ICOB GI ONLY'
             WHEN (TTL.mcob>0 and TTL.icob >0) or TTL.mcob>0 THEN 'MCOB'
             WHEN TTL.ICOB_Owl >0 THEN 'ICOB_Owl'
             ELSE 'ICOB' 
        END as `business area`,
        TTL.CF30Status
    FROM (
        SELECT 
            uid,
            SUM(CASE WHEN (BusinessArea LIKE 'cob%' AND CF30Status <> 'Not Set') THEN 1 ELSE 0 END) as COB,
            SUM(CASE WHEN BusinessArea LIKE 'mcob%' THEN 1 ELSE 0 END) as MCOB,
            SUM(CASE WHEN BusinessArea LIKE 'icob%' AND BusinessArea NOT LIKE '%Owl%' THEN 1 ELSE 0 END) as ICOB,
            SUM(CASE WHEN BusinessArea LIKE 'icob GI%' THEN 1 ELSE 0 END) as ICOB_GI,
            SUM(CASE WHEN BusinessArea LIKE '%Owl%' THEN 1 ELSE 0 END) as ICOB_Owl,
            CF30Status
        FROM (
            SELECT DISTINCT 
                CASE WHEN UD.USR_ExternalID = '0072' THEN '1008203' 
                     WHEN UD.USR_ExternalID = '1003604' THEN '1005181' 
                     WHEN UD.USR_ExternalID = '1010321' THEN '1010897'
                     WHEN UD.USR_ExternalID = '1010364' THEN '1010744' 
                     WHEN UD.USR_ExternalID = '4001674' THEN '1011586' 
                     ELSE UD.USR_ExternalID 
                END as UID,
                CD.Code_Description as BusinessArea,
                CD2.Code_Description AS CF30Status,
                UC.UC_Status as Status,
                MAX(UC.UC_CompetencyLevel) as Level
            FROM dbo.sa_insight_Licence L 
            INNER JOIN dbo.sa_insight_UserLicence UL ON L.LIC_ID = UL.ULIC_LicenceID 
            RIGHT JOIN dbo.sa_insight_Staff S 
                INNER JOIN dbo.sa_insight_UserDetails UD ON S.STAF_UserID = UD.USR_ID 
                INNER JOIN dbo.sa_insight_UserCompetency UC ON UD.USR_ID = UC.UC_OwnerID 
                ON UL.ULIC_UserID = UD.USR_ID 
            LEFT JOIN dbo.sa_insight_CodeDescription CD ON UC.UC_BusinessArea = CD.Code_Code AND CD.Code_CodeType = 534 
            LEFT JOIN dbo.sa_insight_CodeDescription AS CD2 ON S.STAF_CustomerFunction = CD2.Code_Code AND CD2.Code_CodeType = 530 
            LEFT JOIN dbo.cscv_AgentsHierarchy ah ON ah.agentcode = UD.USR_ExternalID 
            JOIN (
                SELECT UC_OwnerID, MAX(CAST(UC_UpdatedDate AS DATE)) as UpdatedDate
                FROM dbo.sa_insight_UserCompetency UC
                GROUP BY UC_OwnerID
            ) date ON date.UC_OwnerID = UC.UC_OwnerID AND date.UpdatedDate = CAST(uc.UC_UpdatedDate AS DATE)
            WHERE ((UC_Status = 1 OR UC_Status = 0) AND ah.CompetentStatusDescription = 'Left') AND UC.UC_BusinessArea <= 9
            GROUP BY UD.USR_ExternalID, UC.UC_Status, CD.Code_Description, CD2.Code_Description
        ) TL
        GROUP BY uid, CF30Status
    ) TTL
    LEFT JOIN dbo.cscv_AgentsHierarchy ah ON ah.Agentcode = TTL.UID
),

-- CTE for licensing data with OrgUnit
lic2 AS (
    SELECT 
        CASE WHEN LEFT(TT.uid,2) = '00' THEN CONCAT('00', TT.uid)
             WHEN LEFT(TT.uid,1) = '0' THEN CONCAT('000', TT.uid)
             ELSE TT.uid
        END as uid,
        CASE WHEN ah.AgentCategoryDescription = 'Administrator' THEN 'NASP'
             WHEN (TT.cob>0 and TT.mcob>0 and TT.icob >0) or (TT.cob>0 and TT.mcob>0) THEN 'CMCOB'
             WHEN (TT.cob>0 and TT.icob >0) or TT.cob>0 THEN 'COB'
             WHEN TT.ICOB_GI>0 THEN 'ICOB GI ONLY'
             WHEN (TT.mcob>0 and TT.icob >0) or TT.mcob>0 THEN 'MCOB'
             WHEN TT.ICOB_Owl >0 THEN 'ICOB_Owl'
             ELSE 'ICOB' 
        END as `business area`,
        TT.CF30Status,
        CASE WHEN TT.`Date Achieved` IS NOT NULL THEN TT.`Date Achieved` ELSE NULL END as `COB Competency Date`
    FROM (
        SELECT 
            uid,
            SUM(CASE WHEN (BusinessArea LIKE 'cob%' AND CF30Status <> 'Not Set') 
                      OR (BusinessArea LIKE 'cob%' AND OrgUnit = 'A3A2BFF6-80E3-4BBA-9160-604EE9710AF5') THEN 1 ELSE 0 END) as COB,
            SUM(CASE WHEN BusinessArea LIKE 'mcob%' THEN 1 ELSE 0 END) as MCOB,
            SUM(CASE WHEN BusinessArea LIKE 'icob%' AND BusinessArea NOT LIKE '%Owl%' THEN 1 ELSE 0 END) as ICOB,
            SUM(CASE WHEN BusinessArea LIKE 'icob GI%' THEN 1 ELSE 0 END) as ICOB_GI,
            SUM(CASE WHEN BusinessArea LIKE '%Owl%' THEN 1 ELSE 0 END) as ICOB_Owl,
            CF30Status,
            MAX(CASE WHEN (BusinessArea LIKE 'cob%' AND CF30Status <> 'Not Set') 
                      OR (BusinessArea LIKE 'cob%' AND OrgUnit = 'A3A2BFF6-80E3-4BBA-9160-604EE9710AF5') THEN 3 ELSE 0 END) as `COB Competency`,
            MAX(CASE WHEN (BusinessArea LIKE 'cob%' AND CF30Status <> 'Not Set') 
                      OR (BusinessArea LIKE 'cob%' AND OrgUnit = 'A3A2BFF6-80E3-4BBA-9160-604EE9710AF5') THEN `Date Achieved` ELSE NULL END) as `Date Achieved`
        FROM (
            SELECT DISTINCT 
                CASE WHEN UD.USR_ExternalID = '0072' THEN '1008203' 
                     WHEN UD.USR_ExternalID = '1003604' THEN '1005181' 
                     WHEN UD.USR_ExternalID = '1010321' THEN '1010897'
                     WHEN UD.USR_ExternalID = '1010364' THEN '1010744' 
                     WHEN UD.USR_ExternalID = '4001674' THEN '1011586' 
                     ELSE UD.USR_ExternalID 
                END as UID,
                CD.Code_Description as BusinessArea,
                CD2.Code_Description AS CF30Status,
                UC.UC_Status as Status,
                MAX(UC.UC_CompetencyLevel) as Level,
                UPS_OrganisationalUnitID as OrgUnit,
                UC.UC_BusinessArea,
                CASE WHEN UC.UC_BusinessArea = 3 THEN CAST(UC.UC_DateAchieved AS DATE) ELSE NULL END as `Date Achieved`
            FROM dbo.sa_insight_Licence L 
            INNER JOIN dbo.sa_insight_UserLicence UL ON L.LIC_ID = UL.ULIC_LicenceID 
            RIGHT JOIN dbo.sa_insight_Staff S 
                INNER JOIN dbo.sa_insight_UserDetails UD ON S.STAF_UserID = UD.USR_ID 
                INNER JOIN dbo.sa_insight_UserCompetency UC ON UD.USR_ID = UC.UC_OwnerID 
                ON UL.ULIC_UserID = UD.USR_ID 
            LEFT JOIN dbo.sa_insight_CodeDescription CD ON UC.UC_BusinessArea = CD.Code_Code AND CD.Code_CodeType = 534 
            LEFT JOIN dbo.sa_insight_CodeDescription AS CD2 ON S.STAF_CustomerFunction = CD2.Code_Code AND CD2.Code_CodeType = 530 
            LEFT JOIN dbo.sa_Insight_UserPosition up ON up.UPS_UserID = UD.USR_ID
            WHERE UC_Status <> 1 AND UC.UC_BusinessArea < 9
            GROUP BY UD.USR_ExternalID, UC.UC_Status, CD.Code_Description, CD2.Code_Description, UC.UC_BusinessArea, UC.UC_DateAchieved, UPS_OrganisationalUnitID
        ) T
        GROUP BY uid, CF30Status
    ) TT
    LEFT JOIN dbo.cscv_AgentsHierarchy ah ON ah.Agentcode = TT.UID
),

-- CTE for Owl Advisers NI/ID
NI_ID AS (
    SELECT 
        USR_ExternalID,
        STAF_Forename,
        STAF_Surname,
        CASE WHEN STAF_NINumber IS NULL 
             THEN CONCAT(STAF_Surname, CAST(STAF_DOB AS DATE)) 
             ELSE STAF_NINumber 
        END AS ID,
        COALESCE(ah.AgentLeftDate, '3030-01-01') as AgentLeftDate
    FROM dbo.sa_Insight_Staff S 
    JOIN dbo.sa_insight_UserDetails UD ON UD.USR_ID = S.STAF_UserID 
    JOIN dbo.cscv_AgentsHierarchy ah ON USR_ExternalID = ah.AgentCode AND (ah.ASDCode <> '4019902' OR ah.FirmCode <> '2016789')
    WHERE ah.CompetentStatusDescription IN('Left', 'Active')
        AND (TRIM(ah.ASDName) IN ('Pat Mckenna', 'Owl Sales Director') OR ah.ASDName IS NULL)
),

-- CTE for Panel
Panel AS (
    SELECT 
        ag.Code,
        TRIM(ag.descn) as Name,
        ag.AgentTypeDescription,
        ag.CompetentStatusDescription,
        INS.InsightAgentUID,
        INS.Section,
        INS.Panel,
        INS.EffFrom,
        COALESCE(INS.EffTo, '2999-12-31') as EffTo
    FROM dbo.mstt_Agents ag 
    INNER JOIN (
        SELECT 
            InsightAgentUID,
            Section,
            Panel,
            EffFrom,
            COALESCE(EffTo, '2999-12-31') as EffTo 
        FROM dbo.f_Insight_ListPanelHistoryOfAllSellers()
    ) INS ON CASE WHEN LEFT(INS.InsightAgentUID,2) = '00' THEN CONCAT('00', INS.InsightAgentUID)
                  WHEN LEFT(INS.InsightAgentUID,1) = '0' THEN CONCAT('000', INS.InsightAgentUID)
                  ELSE INS.InsightAgentUID
             END = CASE WHEN LENGTH(ag.Code) = 4 THEN CASE WHEN LEFT(ag.Code,2) = '00' THEN CONCAT('00', ag.Code)
                                                         WHEN LEFT(ag.Code,1) = '0' THEN CONCAT('000', ag.Code)
                                                         ELSE ag.Code
                                                    END
                       ELSE ag.CODE 
                  END 
             AND CURRENT_DATE() BETWEEN INS.EffFrom AND INS.EffTo
),

-- CTE for PTS ID
PTS_ID AS (
    SELECT 
        USR_ExternalID,
        STAF_Forename,
        STAF_Surname,
        CASE WHEN STAF_NINumber IS NULL 
             THEN CONCAT(STAF_Surname, CAST(STAF_DOB AS DATE)) 
             ELSE STAF_NINumber 
        END AS ID
    FROM dbo.sa_Insight_Staff S 
    JOIN dbo.sa_insight_UserDetails UD ON UD.USR_ID = S.STAF_UserID 
    JOIN dbo.cscv_AgentsHierarchy ah ON USR_ExternalID = ah.AgentCode AND (ah.ASDCode <> '4019902' OR ah.FirmCode <> '2016789')
    WHERE ah.CompetentStatusDescription IN('Left', 'Active')
        AND (ah.ASDCode NOT IN('4019902') AND ah.FirmCode <> '2016789')
        AND (ah.AgentDesc LIKE '%1%' OR ah.AgentDesc LIKE '%(PTS)%')
),

-- CTE for NOT PTS ID
NOT_PTS_ID AS (
    SELECT 
        USR_ExternalID as `Competency ID`,
        STAF_Forename as Forename,
        STAF_Surname as Surname,
        CASE WHEN STAF_NINumber IS NULL 
             THEN CONCAT(STAF_Surname, CAST(STAF_DOB AS DATE)) 
             ELSE STAF_NINumber 
        END AS Link_ID
    FROM dbo.sa_Insight_Staff S 
    JOIN dbo.sa_insight_UserDetails UD ON UD.USR_ID = S.STAF_UserID
),

-- CTE for Competency ID
Competency_ID AS (
    SELECT *
    FROM PTS_ID
    LEFT JOIN NOT_PTS_ID ON NOT_PTS_ID.Link_ID = PTS_ID.ID AND NOT_PTS_ID.Surname NOT LIKE '%1%'
    WHERE `Competency ID` IS NOT NULL
),

-- CTE for PTS Competency
PTS_Competency AS (
    SELECT 
        USR_ExternalID,
        Forename,
        Surname,
        lic2.`business area`,
        lic2.`COB Competency Date`
    FROM Competency_ID 
    LEFT JOIN lic2 ON lic2.UID = Competency_ID.`Competency ID`
    WHERE lic2.`business area` IS NOT NULL
),

-- CTE for final Adviser Table
AdviserTable AS (
    SELECT DISTINCT 
        TRIM(REPLACE(REPLACE(REPLACE(ah.AgentCode, CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Adviser UID`,
        TRIM(ah.AgentDesc) as `Adviser Name`,
        ah.CompetentStatusdescription as `Swift Status`,
        COALESCE(CD.Code_Description, '') as `Insight Status`,
        CASE WHEN ah.ASDCode IN ('4005013','4021409') AND ah.AgentTypeDescription = 'Principal' THEN 
                CASE WHEN uh.UserJobTitleCodeSeller IS NOT NULL THEN
                    CASE UserJobTitleCodeSeller WHEN 61 THEN 'Senior Protection Adviser'
                                                WHEN 62 THEN 'Mortgage Adviser'
                                                WHEN 63 THEN 'New Protection Adviser'
                    ELSE 'Protection Adviser' 
                    END
                ELSE 'Adviser' END
            ELSE CASE WHEN ah.AgentTypeDescription = 'Seller' THEN 'Adviser'
                      WHEN ah.agenttype IN (42,46) THEN 'Franchise'
                      ELSE ah.AgentTypeDescription 
                 END 
        END as Type,
        CAST(ah.AgentStartDate AS DATE) as DOJ,
        CAST(ah.AgentLeftDate AS DATE) as DOL,
        COALESCE(ag.ReasonForLeaving, '') as `Reason For Leaving`,
        CASE WHEN ah.AgentTypeDescription = 'Franchise' THEN ah.AgentCode ELSE ah.FirmCode END as `Firm UID`,
        TRIM(ah.FirmDescn) as `Firm Name`,
        ag3.descn as SDC,
        COALESCE(uh.Supervisorname, '') as `Supervisor Name`,
        COALESCE(ah.rsmname, '') as `RSM Name`,
        COALESCE(uh.BQMName, '') as `QRM Name`,
        COALESCE(uh.AQMName, '') as `AQM Name`,
        COALESCE(ah.ASDCode, '') as `ASD UID`,
        COALESCE(ah.ASDname, '') as `ASD Name`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMUID1, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM UID 1`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMName1, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM Name 1`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMUID2, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM UID 2`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMName2, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM Name 2`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMUID3, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM UID 3`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMName3, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM Name 3`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMUID4, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM UID 4`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMName4, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM Name 4`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMUID5, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM UID 5`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMName5, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM Name 5`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMUID6, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM UID 6`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMName6, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM Name 6`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMUID7, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM UID 7`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMName7, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM Name 7`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMUID8, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM UID 8`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMName8, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM Name 8`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMUID9, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM UID 9`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMName9, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM Name 9`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMUID10, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM UID 10`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(uh.OwlASMName10, ''), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Owl ASM Name 10`,
        CAST(cl.BIRTHDATE AS DATE) as DOB,
        MONTH(cl.BIRTHDATE) as `Birth Month`,
        FLOOR(DATEDIFF(CURRENT_DATE(), cl.BIRTHDATE) / 365.25) AS Age,
        CASE WHEN cl.Gender = 'U' THEN 
                CASE WHEN COALESCE(CD2.Code_Description, '') = 'Female' THEN 'F'
                     WHEN COALESCE(CD2.Code_Description, '') = 'Male' THEN 'M'
                     WHEN COALESCE(CD2.Code_Description, '') IS NULL THEN ''
                     ELSE COALESCE(CD2.Code_Description, '')
                END
             WHEN COALESCE(cl.Gender, CD2.Code_Description) = 'Female' THEN 'F'
             WHEN COALESCE(cl.Gender, CD2.Code_Description) = 'Male' THEN 'M'
             WHEN COALESCE(cl.Gender, CD2.Code_Description) IS NULL THEN ''
             WHEN COALESCE(cl.Gender, CD2.Code_Description) = 'N' THEN 'F'
             ELSE COALESCE(cl.Gender, CD2.Code_Description) 
        END as Gender,
        FLOOR(DATEDIFF(CURRENT_DATE(), cl.BIRTHDATE) / 365.25) + 1 as Age_Next_Birthday,
        CASE WHEN LEFT(ag2.AgentCategoryDescription, 4) = 'NASP' AND ah.AgentCategoryDescription = 'Administrator' THEN 'NASP' 
             ELSE CASE WHEN ((ah.AgentDesc LIKE '%(PTS)%' AND ah.FirmCode = '2000812') 
                            OR ah.AgentDesc LIKE '%Jennings 1') THEN PTSComp.`business area`
                       WHEN ((ah.AgentDesc LIKE '%1%' AND ah.FirmCode = '2004728')
                            OR (ah.AgentDesc LIKE '%Hillier 1')) THEN PTSComp.`business area`
                       ELSE CASE WHEN ah.CompetentStatusdescription = 'Active' THEN lic.`business area` 
                                 ELSE Leavelic.`business area`
                            END
                  END 
        END as `Licensed As`,
        CASE WHEN LEFT(ag2.AgentCategoryDescription, 4) = 'NASP' AND ah.AgentCategoryDescription = 'Administrator' THEN NULL 
             ELSE CASE WHEN ((ah.AgentDesc LIKE '%(PTS)%' AND ah.FirmCode = '2000812') 
                            OR ah.AgentDesc LIKE '%Jennings 1') THEN PTSComp.`COB Competency Date`
                       WHEN ((ah.AgentDesc LIKE '%1%' AND ah.FirmCode = '2004728')
                            OR (ah.AgentDesc LIKE '%Hillier 1')) THEN PTSComp.`COB Competency Date`
                       ELSE lic.`COB Competency Date` 
                  END 
        END as `COB Competency Date`,
        lic.CF30Status as `CF30 Status`,
        CASE WHEN ah.ASDCode IN ('4005013','4021409') THEN 'Owl' ELSE 'Openwork' END AS Channel,
        CASE WHEN Link.USR_ExternalID IS NULL THEN '' 
             WHEN Link.USR_ExternalID IS NOT NULL AND 
                  CASE WHEN ah.ASDCode IN ('4005013','4021409') THEN 'Owl' ELSE 'Openwork' END = 'Openwork' 
                  AND Link.AgentLeftDate < S.STAF_DateFrom THEN ''
             ELSE Link.USR_ExternalID 
        END AS Owl_AgentCode,
        CASE WHEN Link.USR_ExternalID IS NULL THEN 'Appointment' 
             WHEN Link.USR_ExternalID IS NOT NULL AND 
                  CASE WHEN ah.ASDCode IN ('4005013','4021409') THEN 'Owl' ELSE 'Openwork' END = 'Owl' THEN 'Appointment'
             WHEN Link.USR_ExternalID IS NOT NULL AND 
                  CASE WHEN ah.ASDCode IN ('4005013','4021409') THEN 'Owl' ELSE 'Openwork' END = 'Openwork' 
                  AND Link.AgentLeftDate < S.STAF_DateFrom THEN 'Appointment'
             ELSE 'Transfer to AR' 
        END AS OWL_AR_Recruitment_Source,
        COALESCE(ag.email, cl.EMAIL) as Email,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(s_cl.CorrAddress1, ag.address1), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Address Line 1`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(s_cl.CorrAddress2, ag.address2), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Address Line 2`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(s_cl.CorrAddress3, ag.address3), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Address Line 3`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(s_cl.CorrTown, ag.address4), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Address Line 4`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(s_cl.CorrCounty, ag.address5), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as `Address Line 5`,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(s_cl.CorrPostcode, ag.postcode), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) as Postcode,
        TRIM(REPLACE(REPLACE(REPLACE(COALESCE(COALESCE(COALESCE(ag.telephone, ins_con.cd_Telephone), cl.TEL_HOME), ins_con.CD_Mobile), CHAR(9), ''), CHAR(10), ''), CHAR(13), '')) AS Telephone,
        ag2.telephone AS `Firm Telephone`,
        ins_con.CD_Mobile as `Mobile Telephone`,
        CASE ag.LicenceNumber WHEN 'Excluded' THEN NULL ELSE ag.LicenceNumber END as `Licence Number`,
        CASE ag2.LicenceNumber WHEN 'Excluded' THEN NULL ELSE ag2.LicenceNumber END as `Firm Ref`,
        CASE ag.Salutation WHEN 'Ocademy' THEN 'Yes' ELSE 'No' END as Ocademy,
        Panel.Panel,
        CASE WHEN (RIGHT(ag.SupervisorTypeCode, 2) = 'NA' AND ag.GivesAdvice = 'Y') OR ah.AgentCode = '1005202' 
             THEN 'N' ELSE ag.GivesAdvice END AS Gives_Advice,
        ag.DESCN as `Legal name`,
        ag.TradingName as `Trading Name`,
        uh.UserJobTitleCodeSeller,
        CASE WHEN ag.EmploymentType = 0 THEN 'Employed'
             WHEN ag.EmploymentType = 1 THEN 'Self-Employed'
             ELSE 'Not Known'
        END as `Employment Type`
    FROM dbo.mstt_Agents ag 
    INNER JOIN dbo.cscv_AgentsHierarchy ah ON ag.CODE = ah.AgentCode
    LEFT JOIN dbo.mstt_Agents ag2 ON ag.Firm = ag2.code
    LEFT JOIN dbo.mstt_Agents ag3 ON ag3.code = ag.Manager2Code
    LEFT JOIN dbo.mstt_Clients cl ON ah.AgentCode = cl.AgentCode
    LEFT JOIN dbo.mi_insight_UserHierarchyallusers uh ON 
        (CASE WHEN uh.useruid = '0102' THEN '0000102'
              WHEN uh.useruid = '0132' THEN '0000132'
              WHEN uh.useruid = '0111' THEN '0000111'
              ELSE uh.useruid END) = ag.code AND uh.latestrowind = 1
    LEFT JOIN lic lic ON lic.UID = (CASE WHEN ag.CODE = '0060' THEN '000060'
                                        WHEN ag.CODE = '0122' THEN '0000122'
                                        ELSE ag.CODE END)
    LEFT JOIN Leaverslic Leavelic ON Leavelic.UID = (CASE WHEN ag.CODE = '0060' THEN '000060'
                                                         WHEN ag.CODE = '0122' THEN '0000122'
                                                         ELSE ag.CODE END)
    INNER JOIN dbo.msit_S_CLIENT s_cl ON s_cl.CLIENT_NUM = cl.CLIENT_NUM
    LEFT JOIN dbo.sa_insight_UserDetails in_UD ON (CASE WHEN USR_external
