IF OBJECT_ID('tempdb..#AdviserTable') IS NOT NULL
DROP TABLE #AdviserTable
IF OBJECT_ID('tempdb..#lic') IS NOT NULL
DROP TABLE #lic
IF OBJECT_ID('tempdb..#NI_ID') IS NOT NULL
DROP TABLE #NI_ID
IF OBJECT_ID('tempdb..#Lic2') IS NOT NULL
DROP TABLE #Lic2
IF OBJECT_ID('tempdb..#PTS_ID') IS NOT NULL
DROP TABLE #PTS_ID
IF OBJECT_ID('tempdb..#NOT_PTS_ID') IS NOT NULL
DROP TABLE #NOT_PTS_ID
IF OBJECT_ID('tempdb..#Competency_ID') IS NOT NULL
DROP TABLE #Competency_ID
IF OBJECT_ID('tempdb..#PTS_Competency') IS NOT NULL
DROP TABLE #PTS_Competency
IF OBJECT_ID('tempdb..#Panel') IS NOT NULL
DROP TABLE #Panel
IF OBJECT_ID('tempdb..#LeaversLic') IS NOT NULL
DROP TABLE #LeaversLic
/***************************************************************************************************
CODE FOR SELLERS HEADCOUNT ACTIVE SELLERS ONLY.  CAPTURE ACTIVE COMPETENCYS TO DETERMINE SELLERS
LICENCE
***************************************************************************************************/

select 
CASE WHEN LEFT(TT.uid,2) = '00' THEN '00' + TT.uid
	 WHEN LEFT(TT.uid,1) = '0' THEN '000' + TT.uid
	 ELSE TT.uid
	 END as uid
,case when ah.AgentCategoryDescription = 'Administrator' then 'NASP'
	  when (TT.cob>0 and TT.mcob>0 and TT.icob >0) or (TT.cob>0 and TT.mcob>0) then 'CMCOB'
	  when (TT.cob>0 and TT.icob >0) or TT.cob>0 then 'COB'
	  when TT.ICOB_GI>0 then 'ICOB GI ONLY'
	  when (TT.mcob>0 and TT.icob >0) or TT.mcob>0 then 'MCOB'
	  when TT.ICOB_Owl >0 then 'ICOB_Owl'
	  else 'ICOB' end [business area]
, TT.CF30Status
, CASE WHEN TT.[Date Achieved] IS NOT NULL THEN TT.[Date Achieved] ELSE NULL END [COB Competency Date]
into #lic
from

(select uid 
,sum(case when (BusinessArea like 'cob%' AND CF30Status <> 'Not Set') then 1 else 0 end) COB
,sum(case when BusinessArea like 'mcob%' then 1 else 0 end) MCOB
,sum(case when BusinessArea like 'icob%' AND BusinessArea NOT LIKE '%Owl%' then 1 else 0 end) ICOB
,sum(case when BusinessArea like 'icob GI%' then 1 else 0 end) ICOB_GI
,sum(case when BusinessArea like '%Owl%' then 1 else 0 end) ICOB_Owl
,CF30Status
, MAX(case when (BusinessArea like 'cob%' AND CF30Status <> 'Not Set') then 3 else 0 end) [COB Competency]
, MAX (case when (BusinessArea like 'cob%' AND CF30Status <> 'Not Set') then [Date Achieved] ELSE NULL END) [Date Achieved]

 from
	(select distinct case when UD.USR_ExternalID = '0072' then '1008203' when UD.USR_ExternalID = '1003604' then '1005181' when UD.USR_ExternalID = '1010321' then '1010897'
						  when UD.USR_ExternalID = '1010364' then '1010744' when UD.USR_ExternalID = '4001674' then '1011586' else UD.USR_ExternalID end UID 
					,CD.Code_Description BusinessArea
					, CD2.Code_Description AS CF30Status
					,UC.UC_Status Status 
					,Max(UC.UC_CompetencyLevel) Level
					,UC.UC_BusinessArea
					,CASE WHEN UC.UC_BusinessArea = 3 THEN CONVERT(DATE,UC.UC_DateAchieved,103)
					 ELSE ''
					 END [Date Achieved]
	from dbo.sa_insight_Licence L inner join
		dbo.sa_insight_UserLicence UL on L.LIC_ID = UL.ULIC_LicenceID right join
		dbo.sa_insight_Staff S inner join
		dbo.sa_insight_UserDetails UD on S.STAF_UserID = UD.USR_ID inner join
		dbo.sa_insight_UserCompetency UC on UD.USR_ID = UC.UC_OwnerID on UL.ULIC_UserID = UD.USR_ID left join
		dbo.sa_insight_CodeDescription CD on UC.UC_BusinessArea = CD.Code_Code and CD.Code_CodeType = 534 LEFT JOIN
		dbo.sa_insight_CodeDescription AS CD2 ON S.STAF_CustomerFunction = CD2.Code_Code AND CD2.Code_CodeType = 530
	where	UC_Status <> 1	and UC.UC_BusinessArea <=9
	group by UD.USR_ExternalID, UC.UC_Status, CD.Code_Description, CD2.Code_Description, UC.UC_BusinessArea, UC.UC_DateAchieved
	) T
	group by uid, CF30Status) TT

left join dbo.cscv_AgentsHierarchy ah on ah.Agentcode = TT.UID
--------------------------------------------------------------------------------------------------------------------------------------------------------------

/***************************************************************************************************
REVISED CODE FOR SELLERS HEADCOUNT LEAVERS ONLY.  USE THE UPDATED DATE ON THE
USER COMPETENCY INSIGHT TABLE TO GET MAXIMUM DATE LAST UPDATED FOR ADVISERS THAT HAVE LEFT. THE
ASSUMPTION BEING THAT THE DATE THE COMPETENCY WAS ENDED IS THE DATE IT WAS UPDATED AS THERE IS NO
END DATE ON THE SYSTEM
***************************************************************************************************/
select 
CASE WHEN LEFT(TTL.uid,2) = '00' THEN '00' + TTL.uid
	 WHEN LEFT(TTL.uid,1) = '0' THEN '000' + TTL.uid
	 ELSE TTL.uid
	 END as uid
,case when ah.AgentCategoryDescription = 'Administrator' then 'NASP'
	  when (TTL.cob>0 and TTL.mcob>0 and TTL.icob >0) or (TTL.cob>0 and TTL.mcob>0) then 'CMCOB'
	  when (TTL.cob>0 and TTL.icob >0) or TTL.cob>0 then 'COB'
	  when TTL.ICOB_GI>0 then 'ICOB GI ONLY'
	  when (TTL.mcob>0 and TTL.icob >0) or TTL.mcob>0 then 'MCOB'
	  when TTL.ICOB_Owl >0 then 'ICOB_Owl'
	  else 'ICOB' end [business area]
, TTL.CF30Status
into #Leaverslic
from

(select uid 
,sum(case when (BusinessArea like 'cob%' AND CF30Status <> 'Not Set') then 1 else 0 end) COB
,sum(case when BusinessArea like 'mcob%' then 1 else 0 end) MCOB
,sum(case when BusinessArea like 'icob%' AND BusinessArea NOT LIKE '%Owl%' then 1 else 0 end) ICOB
,sum(case when BusinessArea like 'icob GI%' then 1 else 0 end) ICOB_GI
,sum(case when BusinessArea like '%Owl%' then 1 else 0 end) ICOB_Owl
,CF30Status

 from
	(select distinct case when UD.USR_ExternalID = '0072' then '1008203' when UD.USR_ExternalID = '1003604' then '1005181' when UD.USR_ExternalID = '1010321' then '1010897'
						  when UD.USR_ExternalID = '1010364' then '1010744' when UD.USR_ExternalID = '4001674' then '1011586' else UD.USR_ExternalID end UID 
					,CD.Code_Description BusinessArea, CD2.Code_Description AS CF30Status
					,UC.UC_Status Status 
					,Max(UC.UC_CompetencyLevel) Level
	from dbo.sa_insight_Licence L inner join
		dbo.sa_insight_UserLicence UL on L.LIC_ID = UL.ULIC_LicenceID right join
		dbo.sa_insight_Staff S inner join
		dbo.sa_insight_UserDetails UD on S.STAF_UserID = UD.USR_ID inner join
		dbo.sa_insight_UserCompetency UC on UD.USR_ID = UC.UC_OwnerID on UL.ULIC_UserID = UD.USR_ID left join
		dbo.sa_insight_CodeDescription CD on UC.UC_BusinessArea = CD.Code_Code and CD.Code_CodeType = 534 LEFT JOIN
		dbo.sa_insight_CodeDescription AS CD2 ON S.STAF_CustomerFunction = CD2.Code_Code AND CD2.Code_CodeType = 530 LEFT JOIN
		dbo.cscv_AgentsHierarchy ah on ah.agentcode = UD.USR_ExternalID JOIN
		(
			select UC_OwnerID, Max(CAST(UC_UpdatedDate AS DATE)) UpdatedDate
			from dbo.sa_insight_UserCompetency UC
			group by UC_OwnerID
		) date on date.UC_OwnerID = UC.UC_OwnerID AND date.UpdatedDate = CAST(uc.UC_UpdatedDate AS DATE)
	where	((UC_Status = 1 OR UC_Status = 0) AND ah.CompetentStatusDescription = 'Left')	and UC.UC_BusinessArea <=9 
	group by UD.USR_ExternalID, UC.UC_Status, CD.Code_Description, CD2.Code_Description
	) TL
							
group by uid, CF30Status) TTL

left join dbo.cscv_AgentsHierarchy ah on ah.Agentcode = TTL.UID
------------------------------------------------------------------------------------------------------------------------------------------------------------------------

/************************************************************************************************
	Create table of Owl Advisers to show UID, Name and NI Number.  Where no NI Number is on the system
	use a derived code based on Surname and DOB.
************************************************************************************************/
	SELECT	USR_ExternalID 
			,STAF_Forename
			,STAF_SUrname
			,CASE WHEN STAF_NINumber IS NULL 
				THEN CONCAT(STAF_Surname,CONVERT(DATE,STAF_DOB,103)) 
				ELSE STAF_NINumber 
			END AS ID
			,ISNULL(ah.AgentLeftDate, '01-Jan-3030') AgentLeftDate
	INTO #NI_ID
	FROM	[dbo].[sa_Insight_Staff] S JOIN 
			dbo.sa_insight_UserDetails UD on UD.USR_ID = S.STAF_UserID JOIN
			cscv_AgentsHierarchy ah ON USR_ExternalID = ah.AgentCode AND (ah.ASDCode <> '4019902' OR ah.FirmCode <> '2016789') ---excludes Owl AR ASD Code or Kalon Firm Code
	WHERE	ah.CompetentStatusDescription IN('Left', 'Active')
			AND (rtrim(ah.ASDName) IN ('Pat Mckenna', 'Owl Sales Director') OR ah.ASDName is Null) ---Owl Advisers
				

	Select ag.Code 
		   ,rtrim(ag.descn) as Name
		   ,ag.AgentTypeDescription
		   ,ag.CompetentStatusDescription
		   ,INS.InsightAgentUID
		   ,INS.Section
		   ,INS.Panel
		   ,INS.EffFrom
		   ,isnull(INS.EffTo,'31 dec 2999') as EffTo
	INTO #Panel
	from mstt_Agents ag inner join 
		 (select InsightAgentUID,Section,Panel,EffFrom,isnull(EffTo,'31 dec 2999') as EffTo 
            from [dbo].[f_Insight_ListPanelHistoryOfAllSellers]()
			) INS on CASE WHEN LEFT(INS.InsightAgentUID,2) = '00' THEN '00' + INS.InsightAgentUID
						  WHEN LEFT(INS.InsightAgentUID,1) = '0' THEN '000' + INS.InsightAgentUID
						  ELSE INS.InsightAgentUID
					  END = CASE WHEN LEN(ag.Code) = 4 THEN CASE WHEN LEFT(ag.Code,2) = '00' THEN '00' + ag.Code
																 WHEN LEFT(ag.Code,1) = '0' THEN '000' + ag.Code
																 ELSE ag.Code
															END
							 ELSE ag.CODE END and dateadd(dd,0,datediff(dd,0,getdate() )) between INS.EffFrom and INS.EffTo
			  
		 


select 
CASE WHEN LEFT(TT.uid,2) = '00' THEN '00' + TT.uid
	 WHEN LEFT(TT.uid,1) = '0' THEN '000' + TT.uid
	 ELSE TT.uid
	 END as uid
,case when ah.AgentCategoryDescription = 'Administrator' then 'NASP'
	  when (TT.cob>0 and TT.mcob>0 and TT.icob >0) or (TT.cob>0 and TT.mcob>0) then 'CMCOB'
	  when (TT.cob>0 and TT.icob >0) or TT.cob>0 then 'COB'
	  when TT.ICOB_GI>0 then 'ICOB GI ONLY'
	  when (TT.mcob>0 and TT.icob >0) or TT.mcob>0 then 'MCOB'
	  when TT.ICOB_Owl >0 then 'ICOB_Owl'
	  else 'ICOB' end [business area]
, TT.CF30Status
, CASE WHEN TT.[Date Achieved] IS NOT NULL THEN TT.[Date Achieved] ELSE NULL END [COB Competency Date]
into #lic2
from

(select uid 
,sum(case when (BusinessArea like 'cob%' AND CF30Status <> 'Not Set') 
			   OR (BusinessArea like 'cob%' AND OrgUnit = 'A3A2BFF6-80E3-4BBA-9160-604EE9710AF5') then 1 else 0 end) COB
,sum(case when BusinessArea like 'mcob%' then 1 else 0 end) MCOB
,sum(case when BusinessArea like 'icob%' AND BusinessArea NOT LIKE '%Owl%' then 1 else 0 end) ICOB
,sum(case when BusinessArea like 'icob GI%' then 1 else 0 end) ICOB_GI
,sum(case when BusinessArea like '%Owl%' then 1 else 0 end) ICOB_Owl
,CF30Status
, MAX(case when (BusinessArea like 'cob%' AND CF30Status <> 'Not Set') 
			   OR (BusinessArea like 'cob%' AND OrgUnit = 'A3A2BFF6-80E3-4BBA-9160-604EE9710AF5') then 3 else 0 end) [COB Competency]
, MAX (case when (BusinessArea like 'cob%' AND CF30Status <> 'Not Set') 
			   OR (BusinessArea like 'cob%' AND OrgUnit = 'A3A2BFF6-80E3-4BBA-9160-604EE9710AF5') then [Date Achieved] ELSE NULL END) [Date Achieved]

 from
	(select distinct case when UD.USR_ExternalID = '0072' then '1008203' when UD.USR_ExternalID = '1003604' then '1005181' when UD.USR_ExternalID = '1010321' then '1010897'
						  when UD.USR_ExternalID = '1010364' then '1010744' when UD.USR_ExternalID = '4001674' then '1011586' else UD.USR_ExternalID end UID 
					,CD.Code_Description BusinessArea
					, CD2.Code_Description AS CF30Status
					,UC.UC_Status Status 
					,Max(UC.UC_CompetencyLevel) Level
					, UPS_OrganisationalUnitID OrgUnit
					,UC.UC_BusinessArea
					,CASE WHEN UC.UC_BusinessArea = 3 THEN CONVERT(DATE,UC.UC_DateAchieved,103)
					 ELSE ''
					 END [Date Achieved]
	from dbo.sa_insight_Licence L inner join
		dbo.sa_insight_UserLicence UL on L.LIC_ID = UL.ULIC_LicenceID right join
		dbo.sa_insight_Staff S inner join
		dbo.sa_insight_UserDetails UD on S.STAF_UserID = UD.USR_ID inner join
		dbo.sa_insight_UserCompetency UC on UD.USR_ID = UC.UC_OwnerID on UL.ULIC_UserID = UD.USR_ID left join
		dbo.sa_insight_CodeDescription CD on UC.UC_BusinessArea = CD.Code_Code and CD.Code_CodeType = 534 LEFT JOIN
		dbo.sa_insight_CodeDescription AS CD2 ON S.STAF_CustomerFunction = CD2.Code_Code AND CD2.Code_CodeType = 530 LEFT JOIN
		dbo.sa_Insight_UserPosition up ON up.UPS_UserID = UD.USR_ID
	where	UC_Status <> 1	and UC.UC_BusinessArea <9
	group by UD.USR_ExternalID, UC.UC_Status, CD.Code_Description, CD2.Code_Description, UC.UC_BusinessArea, UC.UC_DateAchieved, UPS_OrganisationalUnitID
	) T
	group by uid, CF30Status) TT

left join dbo.cscv_AgentsHierarchy ah on ah.Agentcode = TT.UID
--------------



SELECT	USR_ExternalID 
			,STAF_Forename
			,STAF_Surname
			,CASE WHEN STAF_NINumber IS NULL 
				THEN CONCAT(STAF_Surname,CONVERT(DATE,STAF_DOB,103)) 
				ELSE STAF_NINumber 
			END AS ID
	INTO #PTS_ID
	FROM	[dbo].[sa_Insight_Staff] S JOIN 
			dbo.sa_insight_UserDetails UD on UD.USR_ID = S.STAF_UserID JOIN
			cscv_AgentsHierarchy ah ON USR_ExternalID = ah.AgentCode AND (ah.ASDCode <> '4019902' OR ah.FirmCode <> '2016789') ---excludes Owl AR ASD Code or Kalon Firm Code
	WHERE	ah.CompetentStatusDescription IN('Left', 'Active')
			AND (ah.ASDCode NOT IN('4019902') 
			AND ah.FirmCode <> '2016789')
			AND (ah.AgentDesc Like '%1%' or ah.AgentDesc liKe'%(PTS)%')


SELECT	USR_ExternalID [Competency ID]
			,STAF_Forename Forename
			,STAF_Surname Surname
			,CASE WHEN STAF_NINumber IS NULL 
				THEN CONCAT(STAF_Surname,CONVERT(DATE,STAF_DOB,103)) 
				ELSE STAF_NINumber 
			END AS Link_ID
	INTO #NOT_PTS_ID
	FROM	[dbo].[sa_Insight_Staff] S JOIN 
			dbo.sa_insight_UserDetails UD on UD.USR_ID = S.STAF_UserID 



Select * 
INTO #Competency_ID
from #PTS_ID
		 LEFT JOIN #Not_PTS_ID ON #Not_PTS_ID.Link_id = #PTS_ID.id AND #Not_PTS_ID.Surname NOT LIKE ('%1%')
Where [Competency ID] IS NOT NULL
 

Select USR_ExternalID, Forename, Surname, #Lic2.[business area], #Lic2.[COB Competency Date] 
INTO #PTS_Competency
from #Competency_ID LEFT JOIN
	 #Lic2 on #Lic2.UID = #Competency_ID.[Competency ID]  	
Where #Lic2.[business area] IS NOT NULL	

	

SELECT		REPLACE(REPLACE(REPLACE(ltrim(rtrim(ah.AgentCode)), Char(9),''), Char(10),''), Char(13),'') [Adviser UID]
			,ltrim(rtrim(ah.AgentDesc)) [Adviser Name]
			,ah.CompetentStatusdescription [Swift Status]
			,ISNULL(CD.Code_Description,'') [Insight Status]
			,CASE WHEN ah.ASDCode in ('4005013','4021409') AND ah.AgentTypeDescription = 'Principal' Then 
					CASE WHEN uh.UserJobTitleCodeSeller IS NOT NULL THEN
										CASE UserJobTitleCodeSeller WHEN 61 THEN 'Senior Protection Adviser'
																	WHEN 62 THEN 'Mortgage Adviser'
																	WHEN 63 THEN 'New Protection Adviser'
										ELSE 'Protection Adviser' 
										END
					ELSE 'Adviser' END
			  ELSE case when ah.AgentTypeDescription = 'Seller' then 'Adviser'
						when ah.agenttype in (42,46) then 'Franchise'
						else ah.AgentTypeDescription 
						END 
			end Type
			--,ISNULL(CD2.Code_Description,'') [Insight Experience Level]
			,CAST(ah.AgentStartDate AS Date) 'DOJ'
			,CAST(ah.AgentLeftDate AS Date)'DOL'	
			--,ISNULL(uh.UserReasonforLeavingNotes,'') [Reason for Leaving]
			,ISNULL(ag.ReasonForLeaving,'') [Reason For Leaving]
			,CASE WHEN ah.AgentTypeDescription = 'Franchise' THEN ah.AgentCode
			 ELSE ah.FirmCode
			 END [Firm UID]
		   ,ltrim(rtrim(ah.FirmDescn)) [Firm Name]
		   ,ag3.descn SDC
		   ,ISNULL(uh.Supervisorname,'') [Supervisor Name]
		   ,ISNULL(ah.rsmname,'') [RSM Name]
		   ,ISNULL(uh.BQMName, '') [QRM Name]
		   ,ISNULL(uh.AQMName,'') [AQM Name]
		   ,ISNULL(ah.ASDCode,'') [ASD UID]
		   ,ISNULL(ah.ASDname,'') [ASD Name]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMUID1, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM UID 1]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMName1, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM Name 1]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMUID2, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM UID 2]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMName2, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM Name 2]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMUID3, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM UID 3]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMName3, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM Name 3]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMUID4, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM UID 4]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMName4, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM Name 4]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMUID5, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM UID 5]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMName5, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM Name 5]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMUID6, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM UID 6]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMName6, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM Name 6]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMUID7, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM UID 7]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMName7, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM Name 7]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMUID8, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM UID 8]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMName8, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM Name 8]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMUID9, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM UID 9]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMName9, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM Name 9]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMUID10, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM UID 10]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(ISNULL(uh.OwlASMName10, ''))), Char(9),''), Char(10),''), Char(13),'') [Owl ASM Name 10]
		   ,CAST(cl.BIRTHDATE AS DATE) DOB
		   ,MONTH(cl.BIRTHDATE) [Birth Month]
		   ,(CONVERT(int,CONVERT(char(8),GETDATE(),112))-CONVERT(char(8),cl.BIRTHDATE,112))/10000 AS Age
		   ,CASE WHEN cl.Gender = 'U' THEN CASE WHEN ISNULL(CD2.Code_Description, '') = 'Female' THEN 'F'
												WHEN ISNULL(CD2.Code_Description, '') = 'Male' THEN 'M'
												WHEN ISNULL(CD2.Code_Description, '') IS NULL THEN ''
												ELSE ISNULL(CD2.Code_Description, '')
									  END
				 WHEN ISNULL(cl.Gender, CD2.Code_Description) = 'Female' THEN 'F'
				 WHEN ISNULL(cl.Gender, CD2.Code_Description) = 'Male' THEN 'M'
				 WHEN ISNULL(cl.Gender, CD2.Code_Description) IS NULL THEN ''
				 WHEN ISNULL(cl.Gender, CD2.Code_Description) = 'N' THEN 'F'
		   ELSE ISNULL(cl.Gender, CD2.Code_Description) END Gender
		   ,(datediff(d,cl.BIRTHDATE,GETDATE())/365)+1 Age_Next_Birthday
		   --,case when left(ag2.AgentCategoryDescription, 4) = 'NASP' and ah.AgentCategoryDescription = 'Administrator' then 'NASP' else '' end [NASP Flag]
		   ,case when left(ag2.AgentCategoryDescription, 4) = 'NASP' and ah.AgentCategoryDescription = 'Administrator' then 'NASP' 
		    else CASE WHEN ((ah.AgentDesc LIKE '%(PTS)%' AND ah.FirmCode = '2000812') 
							OR ah.AgentDesc LIKE '%Jennings 1') THEN PTSComp.[Business Area]
					  WHEN  ((ah.AgentDesc LIKE '%1%' AND ah.FirmCode = '2004728')
							 OR (ah.AgentDesc LIKE '%Hillier 1'))THEN PTSComp.[Business Area]
			          ELSE CASE WHEN ah.CompetentStatusdescription = 'Active' THEN lic.[business area] 
						    ELSE Leavelic.[Business Area]
							END
					  END 
			 end 'Licensed As'
		   ,case when left(ag2.AgentCategoryDescription, 4) = 'NASP' and ah.AgentCategoryDescription = 'Administrator' then NULL 
		    else CASE WHEN ((ah.AgentDesc LIKE '%(PTS)%' AND ah.FirmCode = '2000812') 
							OR ah.AgentDesc LIKE '%Jennings 1') THEN PTSComp.[COB Competency Date]
					  WHEN  ((ah.AgentDesc LIKE '%1%' AND ah.FirmCode = '2004728')
							 OR (ah.AgentDesc LIKE '%Hillier 1')) THEN PTSComp.[COB Competency Date]
			          ELSE lic.[COB Competency Date] 
					  END 
			 end 'COB Competency Date'
		   ,lic.CF30Status [CF30 Status]
		 --  ,CASE WHEN (ah.ASDCode in('4019902') OR ah.FirmCode = '2016789' OR ah.AgentCode = '2016789') THEN 'Owl AR' 
			--	 WHEN ah.ASDCode in ('4005013','4021409') Then 'Owl'  
			--	 ELSE 'Openwork' 
			--END AS Channel
		   ,CASE WHEN ah.ASDCode in ('4005013','4021409') Then 'Owl'  
				 ELSE 'Openwork' 
			END AS Channel
		   ,CASE WHEN Link.USR_ExternalID IS NULL 
				 THEN '' 
				 WHEN Link.USR_ExternalID IS NOT NULL AND CASE WHEN ah.ASDCode in ('4005013','4021409') Then 'Owl'  
															  ELSE 'Openwork' END = 'Openwork' AND Link.AgentLeftDate < S.STAF_DateFrom THEN ''
				 ELSE Link.USR_ExternalID 
			END AS Owl_AgentCode
	
		   ,CASE WHEN Link.USR_ExternalID IS NULL 
				THEN 'Appointment' 
				WHEN Link.USR_ExternalID IS NOT NULL AND CASE WHEN ah.ASDCode in ('4005013','4021409') Then 'Owl'  
															  ELSE 'Openwork' END = 'Owl' THEN 'Appointment'
				WHEN Link.USR_ExternalID IS NOT NULL AND CASE WHEN ah.ASDCode in ('4005013','4021409') Then 'Owl'  
															  ELSE 'Openwork' END = 'Openwork' AND Link.AgentLeftDate < S.STAF_DateFrom THEN 'Appointment'
				ELSE 'Transfer to AR' 
			END AS OWL_AR_Recruitment_Source
		   ,isnull(ag.email,cl.EMAIL) Email
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(isnull(s_cl.CorrAddress1,ag.address1))), Char(9),''), Char(10),''), Char(13),'') [Address Line 1]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(isnull(s_cl.CorrAddress2,ag.address2))), Char(9),''), Char(10),''), Char(13),'') [Address Line 2]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(isnull(s_cl.CorrAddress3,ag.address3))), Char(9),''), Char(10),''), Char(13),'') [Address Line 3]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(isnull(s_cl.CorrTown,ag.address4))), Char(9),''), Char(10),''), Char(13),'') [Address Line 4]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(isnull(s_cl.CorrCounty,ag.address5))), Char(9),''), Char(10),''), Char(13),'') [Address Line 5]
		   ,REPLACE(REPLACE(REPLACE(ltrim(rtrim(isnull(s_cl.CorrPostcode,ag.postcode))), Char(9),''), Char(10),''), Char(13),'') Postcode
		   
		   ,REPLACE(REPLACE(REPLACE(isnull(isnull(isnull(ag.telephone,ins_con.cd_Telephone),cl.TEL_HOME),ins_con.CD_Mobile), Char(9),''), Char(10),''), Char(13),'') AS Telephone

		   ,ag2.telephone AS [Firm Telephone]
		   ,ins_con.CD_Mobile [Mobile Telephone]
		   ,case ag.LicenceNumber when 'Excluded' then null else ag.LicenceNumber end [Licence Number]
		   ,case ag2.LicenceNumber when 'Excluded' then null else ag2.LicenceNumber end [Firm Ref]
		   ,case ag.Salutation when 'Ocademy' then 'Yes' else 'No' end Ocademy
		   ,Panel.Panel
		   ,CASE WHEN (RIGHT(ag.SupervisorTypeCode, 2) = 'NA' AND ag.GivesAdvice = 'Y') OR ah.AgentCode = '1005202' 
				THEN 'N' ELSE ag.GivesAdvice END AS Gives_Advice
		   ,ag.DESCN [Legal name]
           ,ag.TradingName [Trading Name]
		   ,uh.UserJobTitleCodeSeller
		   ,Case WHEN ag.EmploymentType = 0 THEN 'Employed'
		    WHEN ag.EmploymentType = 1 THEN 'Self-Employed'
			ELSE 'Not Known'
			END [Employment Type]
INTO #AdviserTable	           
FROM         dbo.mstt_Agents ag inner join dbo.cscv_AgentsHierarchy ah ON ag.CODE = ah.AgentCode
                      left join mstt_Agents ag2 ON ag.Firm = ag2.code
					  left join mstt_Agents ag3 on ag3.code = ag.Manager2Code
                      left join dbo.mstt_Clients cl ON ah.AgentCode = cl.AgentCode
					  left join mi_insight_UserHierarchyallusers uh on (CASE WHEN uh.useruid = '0102' THEN '0000102'
																			 WHEN uh.useruid = '0132' THEN '0000132'
																			 WHEN uh.useruid = '0111' THEN '0000111'
																			 ELSE uh.useruid END) = ag.code and uh.latestrowind = 1
					  left join #lic lic on lic.UID = (CASE WHEN ag.CODE = '0060' THEN '000060'
														  WHEN ag.CODE = '0122' THEN '0000122'
														  ELSE ag.CODE END)
					  left join #Leaverslic Leavelic on Leavelic.UID = (CASE WHEN ag.CODE = '0060' THEN '000060'
														  WHEN ag.CODE = '0122' THEN '0000122'
														  ELSE ag.CODE END)
					  -- contact details - swift and insight
					  inner join dbo.msit_S_CLIENT s_cl on s_cl.CLIENT_NUM = cl.CLIENT_NUM
					  left join dbo.sa_insight_UserDetails in_UD on (CASE WHEN USR_externalid = '0102' THEN '0000102' 
																		  WHEN USR_externalid = '0132' THEN '0000132' 
																		  WHEN USR_externalid = '0111' THEN '0000111'
																		  ELSE USR_externalid END)  = ag.code
					  left join dbo.sa_insight_Staff S on s.STAF_UserID = in_UD.USR_ID
					  left join dbo.sa_insight_ContactDetails ins_con ON  ins_con.CD_ParentID = S.STAF_ID
					  Left join dbo.sa_insight_CodeDescription CD on S.STAF_ContractStatus = CD.Code_Code and CD.Code_CodeType = 527 
					  Left join dbo.sa_insight_CodeDescription CD2 on S.STAF_Gender = CD2.Code_Code and CD2.Code_CodeType = 5
					  left join #NI_ID Link ON Link.ID = (CASE WHEN S.STAF_NINumber IS NULL 
								THEN CONCAT(S.STAF_Surname,CONVERT(DATE,S.STAF_DOB,103)) 
								ELSE S.STAF_NINumber 
							END) AND Link.USR_ExternalID <> ah.AgentCode
					  left join #Panel Panel ON Panel.Code = ah.AgentCode
					  left join #PTS_Competency PTSComp on PTSComp.USR_ExternalID = (CASE WHEN ag.CODE = '0060' THEN '000060'
																					 WHEN ag.CODE = '0122' THEN '0000122'
																					 ELSE ag.CODE END)
					  --left join	dbo.sa_Insight_UserPosition up on in_UD.Usr_ID = ups_UserID
					  --Left join dbo.sa_insight_CodeDescription CD2 on up.UPS_ExperienceLevel = CD2.Code_Code and CD2.Code_CodeType = 524 
						

WHERE 
		(ah.CompetentStatusdescription IN('Active', 'Left', 'Pre-Appointed') -- AND STAF_ContractStatus = 1)
			and (case when (RIGHT(ag.SupervisorTypeCode, 2) = 'NA' AND ag.givesAdvice = 'Y') OR
                      ah.AgentCode = '1005202' then 'N' else ag.GivesAdvice end = 'Y' OR
				case when left(ag2.AgentCategoryDescription, 4) = 'NASP' and ah.AgentCategoryDescription = 'Administrator' then 'NASP' else null end IS NOT NULL)
			and (ah.FirmTypeDescription not like 'Directly Authorised') --and ah.agentcode = '4022160'
or ((ah.agenttype in (42,46) or ah.AgentTypeDescription = 'Franchise') AND ah.CompetentStatusdescription IN('Active', 'Left', 'Pre-Contract') AND ah.ASDCode not in ('4005013','4021409')))

Select DISTINCT * from #AdviserTable 
WHERE CASE WHEN #AdviserTable.[Swift Status] = 'Left' AND #AdviserTable.DOL IS NULL Then 0
		   ELSE 1
	  END = 1
AND 
#AdviserTable.[Adviser UID] NOT IN (
'1005260', -- Pre-Appointment Business Not true Firm
'2001539', -- Duplicated
'1011607', -- OMS payments only
'1011608', -- OMS payments only
'1011609', -- Zurich Independent Wealth Limited OMS payments only
'2001815', -- Lee Newton Financial Services Duplicated
'2004327', -- Open Market Solutions LLP Not true Firm
'2002076', -- Openwork Limited Not AR's
'2000812', -- Openwork National GD Not AR's
'2004728', -- Openwork Corporate Not AR's
'2005603', -- DB Pilot
'2005605', -- Keith Truscott DB Pilot
'4007962', -- Andrew Turner DB Pilot
'2005601', -- Dominic O'Connor DB Pilot
'2005599', -- Andrew Turner DB Pilot
'2007293', -- Claire Dentith DB Pilot
'2007295', -- Darren O'Neill DB Pilot
'2007996', -- Keith Truscott2 DB Pilot
'2008545', -- David Land 
'2008526', -- Sarah Lambert 
'2008591', -- Grant Hutton 
'2008595', -- Peter Ditchburn 
'2008661', -- Luke Best 1 DB Pilot
'2008664', -- Stephen Andrews 1 DB Pilot
'2008666', -- Timothy Felstead 1 DB Pilot
'2008670', -- Paul Fell 1 DB Pilot
'2000873', -- Knights Knox 
'2009072', -- BLS Mortgage & Insurance Services Incorrect
'2000686', -- Grosvenor Berkeley Financial Services Incorrect ID
'2009397', -- Timothy Holmes 1 Pensions Transfer Specialist
'1002915', -- Shaun Terence Matthews 
'2010370', -- Bryan Duchart 1 DB Pilot
'1003227', -- Menai Financial Services Simon Lambell Request
'2011284', -- Liz Miles 1 DB Pilot
'2011287', -- Andrew Earles 1 DB Pilot
'2011312', -- Sarah Hogan 1  DB Pilot
'20122SS', -- Keyed In Error Keyed In Error
'2012714', -- Raymond O'Donnell (PTS) DB Pilot
'2014206', -- Craig Loney 1 
'2015145', -- Planguard Finance 
'4002872', -- Duplicated
'1001025', -- John Sharp Dead
'4003785', -- Lee Newton Duplicated
'4007961', -- Dominic O'Connor (PTS) DB Pilot
'4007959', -- DB Pilot
'1011677', -- Andrew Turner (PTS) DB Pilot
'4007963', -- Keith Truscott1 DB Pilot
'4009489', -- Darren O'Neill1 DB Pilot
'4009488', -- Claire Dentith (PTS) DB Pilot
'4009375', -- Lee Newman Deceased
'4010182', -- GD Ex Clients DUMMY ACCOUNT
'1003350', -- Tracyann Johnson New UID incorrectly created
'4010455', -- Sarah Lambert1 Pensions Specialist
'4010568', -- Stephen Andrews 1 Pensions Specialist
'4010513', -- Peter Ditchburn 1 Pensions Specialist
'4010566', -- Luke Best 1 Pensions Specialist
'4010573', -- Paul Fell 1 Pensions Specialist
'4010511', -- Grant Hutton 1 Pensions Specialist
'4010570', -- Timothy Felstead 1 Pensions Specialist
'4011182', -- Timothy Holmes 1 Pensions Transfer Specialist
'4006771', -- Internal Transfer 
'4011613', -- Mark Jones 1 Tranfer
'4011213', -- Morven Turner Supervising Only
'4012052', -- Bryan Duchart 1 DB Pilot
'1011524', -- Dermot Dowling Requested exclude by Nick Bird - Check if needs to be removed
'4012843', -- Sarah Hogan 1  DB Pilot
'4012821', -- Andrew Earles 1 DB Pilot
'4012820', -- Liz Miles 1 DB Pilot
'401373',  -- Richard Dew Incorrect UID
'4014315', -- Raymond O'Donnell (PTS) DB Pilot
'2011284', -- Liz Miles 1 DB Pilot
'2011287', -- Andrew Earles 1 DB Pilot
'2011312', -- Sarah Hogan 1  DB Pilot
'4015635', -- David Land (PTS)  
'4015829', -- Craig Loney (PTS) 
'4010475', -- David Land 
'1012060', -- Mark Miskimmin OA PBO/Sale purposes and should not report
'1012059', -- Philip White Set up by IT for access
--'4016276', -- Carley Warren-Aldworth 
--'1009390', -- Carley Warren-Aldworth 
'1001168', -- Kenneth Bray Deceased but will not be changed to deceased
'1004297', -- Michael Casburn Deceased but will not be changed to deceased
'112 Roy', -- Incorrect UID
'Bilal M', -- Incorrect UID  
'Catheri', -- Incorrect UID  
'Kurian',  -- Incorrect UID  
'M1 3LD',  -- Incorrect UID  
'Marc To', -- Incorrect UID  
'Michael', -- Incorrect UID  
'Pawel K', -- Incorrect UID  
'SP17028', -- Incorrect UID  
'4000810', -- Andrea Turner (Prosperity) Set up as Seller but not selling & no DT30 Track so exclude by UID
'4023346',  -- Penny Group Pot Account set up AS IAR
'1012745',  -- Simon Jukes OA PBO/Sale purposes and should not report
'1003480',	-- William Lister died but left as active on Swift while new Principal set up
'1012723', -- Sarah Collins OA set up to access OpenAccess for PBO purposes only
'1012827', -- Paul Dalzell 22 OA set to access OpemAccess for PBO purposes
'1012813'  -- Victoria Bone OA set up to access OpenAccess for PBO Purposes
)

AND  #AdviserTable.[Adviser UID] NOT IN (SELECT UD.USR_ExternalID
					 FROM [dbo].[sa_Insight_UserTandCTrack]  usrT
					 JOIN [dbo].[sa_Insight_TandCTrack] T ON T.TCT_ID = usrT.USRT_TrackID
					 JOIN [dbo].[sa_Insight_UserDetails] UD ON UD.USR_ID = usrT.USRT_UserID
					 JOIN [dbo].[sa_Insight_CodeDescription] CD ON CD.Code_Code = usrT.USRT_Status and CD.Code_CodeType = 507
					 WHERE 
					 usrT.USRT_TrackID = '44531ED2-0D60-4E44-8409-30CFFE257004' -- DT30 Track in Insight
					 AND usrT.USRT_Status = 1)
					 

Order by Channel ASC, [Adviser UID] ASC
