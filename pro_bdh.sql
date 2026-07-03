USE [prod_zurich_openwork_datawarehouse]
GO
/****** Object:  StoredProcedure [bdh].[AdviserData]    Script Date: 7/3/2026 3:25:19 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [bdh].[AdviserData]
@jsonData VARCHAR(MAX) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	SET @jsonData = 
	(
		SELECT
				 [AdviserId]
				,[FirmId]
				,[AdviserEmail]
				,[AddressLine1] AS [Address.Line1]
				,[AddressLine2] AS [Address.Line2]
				,[AddressLine3] AS [Address.Line3]
				,[AddressLine4] AS [Address.Line4]
				,[AddressLine5] AS [Address.Line5]
				,[AddressPostalCode] AS [Address.PostalCode]
				,[Competency]
				,[DateOfJoining]
				,[FirstName]
				,[LastName]
				,[QualityAndRiskManagerId]
				,[QualityAndRiskManagerName]
				,[Roles]
				,[Supervisor]
				,[LandlinePhoneNumber]
				,[MobilePhoneNumber]
				,[ProtectionPanel]
				,[Status]
				,[RegionalBusinessConsultant]
				,[BusinessDevelopmentExecutive]
				,[RiskRating]
				,[DateOfBirth]
				,[Licenses]
		FROM	[bdh].[BDHAdviser]
		ORDER BY [AdviserId]
		FOR JSON PATH
	);
END
GO
/****** Object:  StoredProcedure [bdh].[AdviserDataGeneration]    Script Date: 7/3/2026 3:25:19 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE   PROCEDURE [bdh].[AdviserDataGeneration]
AS
/******************************************************************************

Adviser data extract for the Business Development Hub (also know as Adviser CRM)

*******************************************************************************/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	IF OBJECT_ID('tempdb..#Owl') IS NOT NULL
		DROP TABLE #Owl;
	IF OBJECT_ID('tempdb..#BusinessArea') IS NOT NULL
		DROP TABLE #BusinessArea;
	IF OBJECT_ID('tempdb..#ProtectionPanel') IS NOT NULL
		DROP TABLE #ProtectionPanel;
	IF OBJECT_ID('tempdb..#RiskRating') IS NOT NULL
		DROP TABLE #RiskRating;
	IF OBJECT_ID('tempdb..#Licenses') IS NOT NULL
		DROP TABLE #Licenses;
	IF OBJECT_ID('tempdb..#BDHAdviser') IS NOT NULL
		DROP TABLE #BDHAdviser;

	CREATE TABLE #Owl
	(UserUID VARCHAR(7) NOT NULL
	);

	CREATE TABLE #BusinessArea
	([UC_OwnerID]	UNIQUEIDENTIFIER NOT NULL
	,[BusinessArea]	VARCHAR(100) NOT NULL
	);

	CREATE TABLE #ProtectionPanel
	([AdviserId]		VARCHAR(7) NOT NULL
	,[ProtectionPanel]	VARCHAR(100) NOT NULL
	,[RowNum]			BIGINT NOT NULL
	);

	CREATE TABLE #RiskRating
	([AdviserId]	VARCHAR(7) NOT NULL
	,[RiskRating]	VARCHAR(100) NOT NULL
	);

	CREATE TABLE #Licenses
	([AdviserId]	VARCHAR(7) NOT NULL
	,[Licenses]		VARCHAR(255) NOT NULL
	);

	CREATE TABLE #BDHAdviser
	([AdviserId]							VARCHAR(7) NOT NULL
	,[FirmId]								VARCHAR(7) NOT NULL
	,[AdviserEmail]							VARCHAR(100) NOT NULL
	,[AddressLine1]							VARCHAR(35) NOT NULL
	,[AddressLine2]							VARCHAR(35) NOT NULL
	,[AddressLine3]							VARCHAR(35) NOT NULL
	,[AddressLine4]							VARCHAR(35) NOT NULL
	,[AddressLine5]							VARCHAR(35) NOT NULL
	,[AddressPostalCode]					VARCHAR(10) NOT NULL
	,[Competency]							VARCHAR(100) NOT NULL
	,[DateOfJoining]						DATE
	,[FirstName]							VARCHAR(255) NOT NULL
	,[LastName]								VARCHAR(255) NOT NULL
	,[QualityAndRiskManagerId]				VARCHAR(7) NOT NULL
	,[QualityAndRiskManagerName]			VARCHAR(50) NOT NULL
	,[Roles]								VARCHAR(100) NOT NULL
	,[Supervisor]							VARCHAR(7) NOT NULL
	,[LandlinePhoneNumber]					VARCHAR(30) NOT NULL
	,[MobilePhoneNumber]					VARCHAR(30) NOT NULL
	,[ProtectionPanel]						VARCHAR(100) NOT NULL
	,[Status]								VARCHAR(20) NOT NULL
	,[RegionalBusinessConsultant]			VARCHAR(7) NOT NULL
	,[BusinessDevelopmentExecutive]			VARCHAR(7) NOT NULL
	,[RiskRating]							VARCHAR(100) NOT NULL
	,[DateOfBirth]							DATE
	,[Licenses]								VARCHAR(255) NOT NULL
	);

	DECLARE  @Date			DATETIME
			,@Manager2Code	VARCHAR(7)
			;

	/***************************************************************************************************************************************************************************************************
	**	Owl
	***************************************************************************************************************************************************************************************************/
	SET  @Date = CAST( GETDATE() AS DATE );

	SELECT	@Manager2Code = cde.Code
	FROM	dbo.msit_MIWarehouseCodesAndDescriptions cde
	WHERE	cde.ColumnName = 'Manager2Code' 
	AND		cde.Description = 'Owl Financial';

	INSERT	#Owl 
			(UserUID
			)
	/* Insight */
	SELECT	CAST(ud.USR_ExternalID AS VARCHAR(7)) AS UserUID
	FROM		dbo.sa_insight_UserDetails ud
	INNER JOIN	dbo.sa_insight_UserPosition up	ON up.UPS_UserID = ud.USR_ID 
												AND ( up.UPS_DateTo IS NULL OR up.UPS_DateTo > @Date )
												AND ( up.UPS_JobTitle BETWEEN 51 AND 58 OR UP.UPS_JOBTITLE BETWEEN 61 AND 63 )
	WHERE	ud.USR_Name not like '%error%'
	AND		ud.USR_ExternalID IS NOT NULL
	AND		ud.USR_ExternalID <> ''
	UNION
	/* Swift */
	SELECT	 ag.CODE AS UserUID
	FROM	dbo.mstt_Agents ag
	WHERE	ag.CompetentStatusDescription = 'Active' 
	AND		(	ag.DESCN IN ('Pat McKenna', 'Owl Sales Director', 'OWL Area Sales Manager') 
			OR	ag.Manager2Code = @Manager2Code
			);

	/***************************************************************************************************************************************************************************************************
	**	Business Area
	***************************************************************************************************************************************************************************************************/
	INSERT #BusinessArea
		([UC_OwnerID]
		,[BusinessArea]
		)
	SELECT
		 UCT.UC_OwnerID
		,CASE 
			WHEN CD.Code_Description = 'COB' AND UCT2.UC_BusinessArea = 'MCOB' AND LEFT(CD5.Code_Description,4) = 'CF30'  THEN 'CMCOB' 
			WHEN CD.Code_Description = 'ICOB, MCOB and COB' THEN 'CMCOB' 
			WHEN CD.Code_Description = 'ICOB and COB' THEN 'COB' 
			WHEN CD.Code_Description = 'ICOB and MCOB' THEN 'MCOB' 
			WHEN CD.Code_Description = 'COB' AND LEFT(CD5.Code_Description,4) = 'CF30' THEN 'COB'  
			WHEN CD.Code_Description = 'COB' AND UCT2.UC_BusinessArea <> 'MCOB' AND LEFT(CD5.Code_Description,4) <> 'CF30' THEN 'ICOB' 
			WHEN CD.Code_Description = 'COB' AND UCT2.UC_BusinessArea = 'MCOB' AND LEFT(CD5.Code_Description,4) <> 'CF30'  THEN 'MCOB'  
			ELSE CD.Code_Description 
		 END AS BusinessArea
	FROM		(
				SELECT
					 UC.UC_OwnerID
					,MAX(UC.UC_BusinessArea) AS UC_BusinessArea
				FROM	dbo.sa_insight_UserCompetency AS UC
				WHERE	UC.UC_Status <> 1
				AND		UC.UC_BusinessArea < 9
				GROUP BY 
					 UC.UC_OwnerID
				)AS UCT
	LEFT JOIN	(
				SELECT
					 UC.UC_OwnerID
					,'MCOB' AS UC_BusinessArea
				FROM	dbo.sa_insight_UserCompetency AS UC
				WHERE	UC.UC_Status <> 1
				AND		UC.UC_BusinessArea = 2
				GROUP BY 
					 UC.UC_OwnerID
				)AS UCT2	ON UCT2.UC_OwnerID = UCT.UC_OwnerID
	LEFT JOIN	dbo.sa_insight_CodeDescription AS CD ON CD.Code_Code = UCT.UC_BusinessArea AND CD.Code_CodeType = 534 
	LEFT JOIN	dbo.sa_insight_Staff AS S ON S.STAF_UserID = UCT.UC_OwnerID
	LEFT JOIN	dbo.sa_insight_CodeDescription AS CD5 ON CD5.Code_Code = S.STAF_CustomerFunction AND CD5.Code_CodeType = 530 
	LEFT JOIN	dbo.sa_insight_UserPosition AS UP ON UP.UPS_UserID = UCT.UC_OwnerID AND UP.UPS_JobTitle = 3
	LEFT JOIN	dbo.sa_insight_UserPosition AS UP2 ON UP2.UPS_UserID = UCT.UC_OwnerID AND DATEADD(dd, 0, DATEDIFF(dd, 0, GETDATE())) BETWEEN UP2.UPS_DateFrom AND ISNULL(UP2.UPS_DateTo, 'Dec 31, 9999') AND UP2.UPS_JobTitle IN (4, 42) 
	WHERE	(	UP.ups_id IS NOT NULL
			OR	UP2.ups_id IS NOT NULL
			);

	/***************************************************************************************************************************************************************************************************
	**	Protection Panel
	***************************************************************************************************************************************************************************************************/
	INSERT	#ProtectionPanel
		([AdviserId]
		,[ProtectionPanel]
		,[RowNum]
		)
	SELECT
		 CAST(u.UserUID AS VARCHAR(7)) AS [AdviserId]
		,pp.ProtectionPanel
		,ROW_NUMBER() OVER ( PARTITION BY u.UserUID ORDER BY pp.ProtectionPanel ) AS RowNum
	FROM	dbo.mi_insight_UserHierarchyAllUsers u
	JOIN	(
			SELECT	 up.UPS_UserID
					,CASE 
						WHEN cd.Code_Description = '001 - Zurich Plus'					THEN '001 - Zurich Plus' 
						WHEN cd.Code_Description = '005 - Openwork Select'				THEN '005 - Openwork Select' 
						WHEN cd.Code_Description = '007 - Pension Panel Zurich Plus'	THEN '001 - Zurich Plus' 
						WHEN cd.Code_Description = '008 - Pension Panel Select'			THEN '005 - Openwork Select' 
						WHEN cd.Code_Description = '032 - Legal and General Single Tie'	THEN '032 - Legal and General Single Tie' 
						ELSE ''
					 END AS [ProtectionPanel]
					,ROW_NUMBER() OVER (PARTITION BY up.UPS_UserID ORDER BY up.UPS_UpdatedDate DESC) AS RowNum
			FROM	dbo.sa_insight_UserPosition up
			JOIN	dbo.sa_insight_CodeDescription cd ON cd.Code_Code = up.UPS_Section AND cd.Code_CodeType = 53
			WHERE	ups_UserType = 3    --Adviser/Seller
			) AS  pp ON pp.UPS_UserID = u.UserGUID
					AND pp.ProtectionPanel <> ''
					AND pp.RowNum = 1
	WHERE	u.LatestRowInd = 1 
	AND		u.BusinessUID IS NOT NULL 
	AND		u.UserContractStatus = 'Under Contract'
	AND		NOT EXISTS ( SELECT * FROM #Owl o WHERE o.UserUID = u.UserUID ) 
	GROUP BY u.UserUID
			,pp.ProtectionPanel
	ORDER BY u.UserUID
			,pp.ProtectionPanel
			;

	WITH MultiPP AS
	(
	SELECT pp1.AdviserId,
		   STUFF((SELECT ';' + rtrim(convert(VARCHAR(100),pp2.ProtectionPanel))
			FROM   #ProtectionPanel AS pp2
			WHERE  pp2.AdviserId = pp1.AdviserId
			FOR XML PATH('')),1,1,'') ProtectionPanel
	FROM   #ProtectionPanel AS pp1
	WHERE	pp1.RowNum > 1
	GROUP BY pp1.AdviserId
	)
	UPDATE	pp
	SET		pp.ProtectionPanel = mpp.ProtectionPanel
	FROM	#ProtectionPanel pp
	JOIN	MultiPP mpp ON mpp.AdviserId = pp.AdviserId
	WHERE	pp.RowNum = 1
	;

	DELETE	#ProtectionPanel
	WHERE	RowNum > 1;

	/***************************************************************************************************************************************************************************************************
	**	Risk Rating
	***************************************************************************************************************************************************************************************************/
	WITH RiskRating AS
	(
	SELECT
		 CAST(uh.UserUID AS VARCHAR(7)) AS [AdviserId]
		,CASE cd.Code_Description
			WHEN 'Green' THEN 'Green'
			WHEN 'Amber' THEN 'Amber'
			WHEN 'Red' THEN 'Red'
			WHEN 'Red Flag' THEN 'Red'
			ELSE ''
			END AS [RiskRating]
		,ROW_NUMBER() OVER( PARTITION BY uh.UserUID ORDER BY ra.RA_Date DESC ) AS RowNum
	FROM dbo.sa_insight_RiskAssessment ra
	JOIN dbo.sa_insight_CodeDescription cd ON cd.Code_Code = ra.RA_Status AND cd.Code_CodeType = 500
	JOIN dbo.mi_insight_UserHierarchy uh ON uh.UserGUID = RA_USR_ID AND uh.BusinessUID IS NOT NULL AND uh.UserContractStatus = 'Under Contract'
	WHERE ra.RA_Date > DATEADD(YEAR,-1,GETDATE())
	GROUP BY uh.UserUID
			,CASE cd.Code_Description
				WHEN 'Green' THEN 'Green'
				WHEN 'Amber' THEN 'Amber'
				WHEN 'Red' THEN 'Red'
				WHEN 'Red Flag' THEN 'Red'
				ELSE ''
				END
			,ra.RA_Date
	)
	INSERT	#RiskRating
		([AdviserId]
		,[RiskRating]
		)
	SELECT	
		 r.AdviserId
		,r.RiskRating
	FROM	RiskRating r
	WHERE	r.RowNum = 1;

	/***************************************************************************************************************************************************************************************************
	**	License
	***************************************************************************************************************************************************************************************************/
	WITH License AS 
	(
	SELECT 
		 CAST(u.UserUID AS VARCHAR(7)) AS [AdviserId]
		,l.LIC_Description AS [License]
	FROM		dbo.mi_insight_UserHierarchyAllUsers u
	INNER JOIN	dbo.sa_insight_UserLicence AS ul ON ul.ULIC_UserID = u.UserGUID
												AND	UL.ULIC_Status = 2
	INNER JOIN	dbo.sa_insight_Licence AS l ON l.LIC_ID = ul.ULIC_LicenceID
											AND	L.LIC_Code IN	(N'LIC130'
																,N'LIC135'
																,N'LIC030'
																,N'LIC78'
																,N'LIC70'
																,N'LIC69'
																,N'LIC134'
																)
	WHERE	u.LatestRowInd = 1 
	AND		u.BusinessUID IS NOT NULL 
	AND		u.UserContractStatus = 'Under Contract'
	AND		NOT EXISTS ( SELECT * FROM #Owl o WHERE o.UserUID = u.UserUID ) 
	GROUP BY 
		 u.UserUID
		,u.BusinessUID
		,l.LIC_Description
	)
	INSERT #Licenses
		([AdviserId]
		,[Licenses]
		)
	SELECT	 DISTINCT l1.AdviserId
			,STUFF(	(
					SELECT	l2.License + '; '
					FROM	License AS l2 
					WHERE	l2.AdviserId = l1.AdviserId
					AND		l2.License <> ''
					GROUP BY l2.License
					FOR XML PATH(''), TYPE).value('.','VARCHAR(255)')
					, 1, 0, '') AS License
	FROM License AS l1;

	/***************************************************************************************************************************************************************************************************
	**	BDH Adviser Data
	***************************************************************************************************************************************************************************************************/
	INSERT #BDHAdviser
		([AdviserId]
		,[FirmId]
		,[AdviserEmail]
		,[AddressLine1]
		,[AddressLine2]
		,[AddressLine3]
		,[AddressLine4]
		,[AddressLine5]
		,[AddressPostalCode]
		,[Competency]
		,[DateOfJoining]
		,[FirstName]
		,[LastName]
		,[QualityAndRiskManagerId]
		,[QualityAndRiskManagerName]
		,[Roles]
		,[Supervisor]
		,[LandlinePhoneNumber]
		,[MobilePhoneNumber]
		,[ProtectionPanel]
		,[Status]
		,[RegionalBusinessConsultant]
		,[BusinessDevelopmentExecutive]
		,[RiskRating]
		,[DateOfBirth]
		,[Licenses]
		)
	SELECT 
		 CAST(u.UserUID AS VARCHAR(7)) AS [AdviserId]
		,CAST(u.BusinessUID AS VARCHAR(7)) AS [FirmId]
		,cd.CD_email AS [AdviserEmail]
		,ISNULL(LTRIM(RTRIM(CASE WHEN c.ADDRESS1 IS NOT NULL THEN c.ADDRESS1 ELSE b.ADDRESS1 END)),'') AS [AddressLine1]
		,ISNULL(LTRIM(RTRIM(CASE WHEN c.ADDRESS1 IS NOT NULL THEN c.ADDRESS2 ELSE b.ADDRESS2 END)),'') AS [AddressLine2]
		,ISNULL(LTRIM(RTRIM(CASE WHEN c.ADDRESS1 IS NOT NULL THEN c.ADDRESS3 ELSE b.ADDRESS3 END)),'') AS [AddressLine3]
		,ISNULL(LTRIM(RTRIM(CASE WHEN c.ADDRESS1 IS NOT NULL THEN c.ADDRESS4 ELSE b.ADDRESS4 END)),'') AS [AddressLine4]
		,ISNULL(LTRIM(RTRIM(CASE WHEN c.ADDRESS1 IS NOT NULL THEN c.ADDRESS5 ELSE b.ADDRESS5 END)),'') AS [AddressLine5]
		,ISNULL(LTRIM(RTRIM(CASE WHEN c.ADDRESS1 IS NOT NULL THEN c.POSTCODE ELSE b.POSTCODE END)),'') AS [AddressPostalCode]
		,COALESCE(	CASE 
						WHEN (	CASE 
									WHEN (LEFT(b.AgentCategoryDescription, 4) = 'NASP' 
									AND ag.AgentCategoryDescription = 'Administrator') 
									THEN 'NASP' 
									ELSE b.AgentCategoryDescription 
								END) = 'NASP' 
						THEN 'NASP' 
						ELSE ba.BusinessArea 
					END,'') AS [Competency]
		,CAST( COALESCE(ag.OscarDateStarted, ag.DateStarted, s.STAF_DateFrom ) AS DATE ) AS [DateOfJoining]
		,s.STAF_Forename AS [FirstName]
		,CASE WHEN ISNUMERIC(LEFT(REVERSE(s.STAF_Surname), 1)) = 1 THEN REVERSE(SUBSTRING(REVERSE(s.STAF_Surname), CHARINDEX(' ', REVERSE(s.STAF_Surname), 1), LEN(s.STAF_Surname))) ELSE s.STAF_Surname END AS [LastName]
		,ISNULL(CAST(u.BQMUID AS VARCHAR(7)), '') AS [QualityAndRiskManagerId]
		,ISNULL(u.BQMName, '') AS [QualityAndRiskManagerName]
		,ISNULL(cd1.Code_Description+';','')+ISNULL(cd2.Code_Description+';','')+ISNULL(cd3.Code_Description+';','')+ISNULL(cd4.Code_Description+';','') AS [Roles]
		,ISNULL(CAST(u.SupervisorUID AS VARCHAR(7)), '') AS [Supervisor]
		,ISNULL(cd.CD_Telephone, '') AS [LandlinePhoneNumber]
		,ISNULL(cd.CD_Mobile, '') AS [MobilePhoneNumber]
		,ISNULL(pp.ProtectionPanel, '') AS [ProtectionPanel]
		,CASE WHEN u.UserContractStatus = 'Under Contract' THEN 'Active' ELSE 'Inactive' END AS [Status]
		,ISNULL(ag.Manager3Code, '') AS [RegionalBusinessConsultant]
		,ISNULL(ag.Manager2Code, '') AS [BusinessDevelopmentExecutive]
		,ISNULL(rr.RiskRating, '') AS [RiskRating]
		,CAST(s.STAF_DOB AS DATE) AS [DateOfBirth]
		,ISNULL(l.Licenses, '') AS [Licenses]
	FROM		dbo.mi_insight_UserHierarchyAllUsers u
	INNER JOIN	dbo.sa_Insight_Staff s ON s.STAF_UserID = u.UserGUID
	INNER JOIN	dbo.sa_Insight_Address a ON a.ADD_ParentID = s.STAF_ID 
										AND a.ADD_Default = 1
	INNER JOIN	dbo.sa_Insight_ContactDetails cd ON cd.CD_ParentID = s.STAF_ID	
	LEFT JOIN	dbo.sa_insight_UserPosition ups ON ups.UPS_UserID = u.UserGUID 
												AND UPS_UserType = 3 
												AND UPS_DateTo IS NULL
	LEFT JOIN	dbo.sa_Insight_CodeDescription cd1 ON cd1.Code_Code = u.UserJobTitleCodePA AND cd1.Code_CodeType = 54
	LEFT JOIN	dbo.sa_Insight_CodeDescription cd2 ON cd2.Code_Code = u.UserJobTitleCodeSeller AND cd2.Code_CodeType = 54
	LEFT JOIN	dbo.sa_Insight_CodeDescription cd3 ON cd3.Code_Code = u.UserJobTitleCodePartner AND cd3.Code_CodeType = 54
	LEFT JOIN	dbo.sa_Insight_CodeDescription cd4 ON cd4.Code_Code = u.UserJobTitleCodeSupervisor AND cd4.Code_CodeType = 54
	LEFT JOIN	dbo.mstt_Agents ag ON ag.CODE = u.UserUID 
	LEFT JOIN	dbo.mstt_Agents b ON b.CODE = u.BusinessUID
	LEFT JOIN	dbo.mstt_Clients c ON c.AgentCode = u.UserUID
	LEFT JOIN	#BusinessArea ba ON  ba.UC_OwnerID = u.UserGUID
	LEFT JOIN	#ProtectionPanel pp ON pp.AdviserId = u.UserUID
	LEFT JOIN	#RiskRating rr ON rr.AdviserId = u.UserUID
	LEFT JOIN	#Licenses l ON  l.AdviserId = u.UserUID
	WHERE	u.LatestRowInd = 1 
	AND		u.BusinessUID IS NOT NULL 
	AND		u.UserContractStatus = 'Under Contract'
	AND		NOT EXISTS ( SELECT * FROM #Owl o WHERE o.UserUID = u.UserUID ) 
	AND		u.UserUID NOT LIKE 'ptl%';

	/***************************************************************************************************************************************************************************************************
	**	Clean up part 1
	***************************************************************************************************************************************************************************************************/
	DROP TABLE #Owl;
	DROP TABLE #BusinessArea;
	DROP TABLE #ProtectionPanel;
	DROP TABLE #RiskRating;
	DROP TABLE #Licenses;

	/***************************************************************************************************************************************************************************************************
	**	Refresh the Firm data set
	***************************************************************************************************************************************************************************************************/
	BEGIN TRY
		BEGIN TRANSACTION

		/***************************************************************************************************************************************************************************************************
		**	Remove old Adviser deltas
		***************************************************************************************************************************************************************************************************/
		SET  @Date = CAST( DATEADD( DAY, -7, GETDATE() ) AS DATE );

		DELETE	bdh.BDHAdviserDelta
		WHERE	[DateDeltaUploaded] < @Date;

		/***************************************************************************************************************************************************************************************************
		**	Remove missing Firm entries
		***************************************************************************************************************************************************************************************************/
		DELETE	bdh.BDHAdviser
		OUTPUT
				 deleted.[AdviserId]
				,deleted.[FirmId]
				,deleted.[AdviserEmail]
				,deleted.[AddressLine1]
				,deleted.[AddressLine2]
				,deleted.[AddressLine3]
				,deleted.[AddressLine4]
				,deleted.[AddressLine5]
				,deleted.[AddressPostalCode]
				,deleted.[Competency]
				,deleted.[DateOfJoining]
				,deleted.[FirstName]
				,deleted.[LastName]
				,deleted.[QualityAndRiskManagerId]
				,deleted.[QualityAndRiskManagerName]
				,deleted.[Roles]
				,deleted.[Supervisor]
				,deleted.[LandlinePhoneNumber]
				,deleted.[MobilePhoneNumber]
				,deleted.[ProtectionPanel]
				,'Inactive'
				,deleted.[RegionalBusinessConsultant]
				,deleted.[BusinessDevelopmentExecutive]
				,deleted.[RiskRating]
				,deleted.[DateOfBirth]
				,deleted.[Licenses]
		INTO	bdh.BDHAdviserDelta
				([AdviserId]
				,[FirmId]
				,[AdviserEmail]
				,[AddressLine1]
				,[AddressLine2]
				,[AddressLine3]
				,[AddressLine4]
				,[AddressLine5]
				,[AddressPostalCode]
				,[Competency]
				,[DateOfJoining]
				,[FirstName]
				,[LastName]
				,[QualityAndRiskManagerId]
				,[QualityAndRiskManagerName]
				,[Roles]
				,[Supervisor]
				,[LandlinePhoneNumber]
				,[MobilePhoneNumber]
				,[ProtectionPanel]
				,[Status]
				,[RegionalBusinessConsultant]
				,[BusinessDevelopmentExecutive]
				,[RiskRating]
				,[DateOfBirth]
				,[Licenses]
				)
		WHERE	[AdviserId] NOT IN ( SELECT [AdviserId] FROM #BDHAdviser );

		/***************************************************************************************************************************************************************************************************
		**	Create new and update existing Advisers
		***************************************************************************************************************************************************************************************************/
		WITH InsUpd AS
				(
				SELECT
						 [AdviserId]
						,[FirmId]
						,[AdviserEmail]
						,[AddressLine1]
						,[AddressLine2]
						,[AddressLine3]
						,[AddressLine4]
						,[AddressLine5]
						,[AddressPostalCode]
						,[Competency]
						,[DateOfJoining]
						,[FirstName]
						,[LastName]
						,[QualityAndRiskManagerId]
						,[QualityAndRiskManagerName]
						,[Roles]
						,[Supervisor]
						,[LandlinePhoneNumber]
						,[MobilePhoneNumber]
						,[ProtectionPanel]
						,[Status]
						,[RegionalBusinessConsultant]
						,[BusinessDevelopmentExecutive]
						,[RiskRating]
						,[DateOfBirth]
						,[Licenses]
				FROM	#BDHAdviser
				EXCEPT
				SELECT
						 [AdviserId]
						,[FirmId]
						,[AdviserEmail]
						,[AddressLine1]
						,[AddressLine2]
						,[AddressLine3]
						,[AddressLine4]
						,[AddressLine5]
						,[AddressPostalCode]
						,[Competency]
						,[DateOfJoining]
						,[FirstName]
						,[LastName]
						,[QualityAndRiskManagerId]
						,[QualityAndRiskManagerName]
						,[Roles]
						,[Supervisor]
						,[LandlinePhoneNumber]
						,[MobilePhoneNumber]
						,[ProtectionPanel]
						,[Status]
						,[RegionalBusinessConsultant]
						,[BusinessDevelopmentExecutive]
						,[RiskRating]
						,[DateOfBirth]
						,[Licenses]
				FROM	bdh.BDHAdviser
				)
		MERGE bdh.BDHAdviser AS prev
		USING InsUpd AS curr
			ON curr.[AdviserId] = prev.[AdviserId]
		WHEN MATCHED
			THEN
				UPDATE SET
						 [FirmId]						= curr.[FirmId]
						,[AdviserEmail]					= curr.[AdviserEmail]
						,[AddressLine1]					= curr.[AddressLine1]
						,[AddressLine2]					= curr.[AddressLine2]
						,[AddressLine3]					= curr.[AddressLine3]
						,[AddressLine4]					= curr.[AddressLine4]
						,[AddressLine5]					= curr.[AddressLine5]
						,[AddressPostalCode]			= curr.[AddressPostalCode]
						,[Competency]					= curr.[Competency]
						,[DateOfJoining]				= curr.[DateOfJoining]
						,[FirstName]					= curr.[FirstName]
						,[LastName]						= curr.[LastName]
						,[QualityAndRiskManagerId]		= curr.[QualityAndRiskManagerId]
						,[QualityAndRiskManagerName]	= curr.[QualityAndRiskManagerName]
						,[Roles]						= curr.[Roles]
						,[Supervisor]					= curr.[Supervisor]
						,[LandlinePhoneNumber]			= curr.[LandlinePhoneNumber]
						,[MobilePhoneNumber]			= curr.[MobilePhoneNumber]
						,[ProtectionPanel]				= curr.[ProtectionPanel]
						,[Status]						= curr.[Status]
						,[RegionalBusinessConsultant]	= curr.[RegionalBusinessConsultant]
						,[BusinessDevelopmentExecutive]	= curr.[BusinessDevelopmentExecutive]
						,[RiskRating]					= curr.[RiskRating]
						,[DateOfBirth]					= curr.[DateOfBirth]
						,[Licenses]						= curr.[Licenses]
		WHEN NOT MATCHED BY TARGET
			THEN
				INSERT	([AdviserId]
						,[FirmId]
						,[AdviserEmail]
						,[AddressLine1]
						,[AddressLine2]
						,[AddressLine3]
						,[AddressLine4]
						,[AddressLine5]
						,[AddressPostalCode]
						,[Competency]
						,[DateOfJoining]
						,[FirstName]
						,[LastName]
						,[QualityAndRiskManagerId]
						,[QualityAndRiskManagerName]
						,[Roles]
						,[Supervisor]
						,[LandlinePhoneNumber]
						,[MobilePhoneNumber]
						,[ProtectionPanel]
						,[Status]
						,[RegionalBusinessConsultant]
						,[BusinessDevelopmentExecutive]
						,[RiskRating]
						,[DateOfBirth]
						,[Licenses]
						)
				VALUES	(curr.[AdviserId]
						,curr.[FirmId]
						,curr.[AdviserEmail]
						,curr.[AddressLine1]
						,curr.[AddressLine2]
						,curr.[AddressLine3]
						,curr.[AddressLine4]
						,curr.[AddressLine5]
						,curr.[AddressPostalCode]
						,curr.[Competency]
						,curr.[DateOfJoining]
						,curr.[FirstName]
						,curr.[LastName]
						,curr.[QualityAndRiskManagerId]
						,curr.[QualityAndRiskManagerName]
						,curr.[Roles]
						,curr.[Supervisor]
						,curr.[LandlinePhoneNumber]
						,curr.[MobilePhoneNumber]
						,curr.[ProtectionPanel]
						,curr.[Status]
						,curr.[RegionalBusinessConsultant]
						,curr.[BusinessDevelopmentExecutive]
						,curr.[RiskRating]
						,curr.[DateOfBirth]
						,curr.[Licenses]
						)
		OUTPUT
				 inserted.[AdviserId]
				,inserted.[FirmId]
				,inserted.[AdviserEmail]
				,inserted.[AddressLine1]
				,inserted.[AddressLine2]
				,inserted.[AddressLine3]
				,inserted.[AddressLine4]
				,inserted.[AddressLine5]
				,inserted.[AddressPostalCode]
				,inserted.[Competency]
				,inserted.[DateOfJoining]
				,inserted.[FirstName]
				,inserted.[LastName]
				,inserted.[QualityAndRiskManagerId]
				,inserted.[QualityAndRiskManagerName]
				,inserted.[Roles]
				,inserted.[Supervisor]
				,inserted.[LandlinePhoneNumber]
				,inserted.[MobilePhoneNumber]
				,inserted.[ProtectionPanel]
				,inserted.[Status]
				,inserted.[RegionalBusinessConsultant]
				,inserted.[BusinessDevelopmentExecutive]
				,inserted.[RiskRating]
				,inserted.[DateOfBirth]
				,inserted.[Licenses]
		INTO	bdh.BDHAdviserDelta
				([AdviserId]
				,[FirmId]
				,[AdviserEmail]
				,[AddressLine1]
				,[AddressLine2]
				,[AddressLine3]
				,[AddressLine4]
				,[AddressLine5]
				,[AddressPostalCode]
				,[Competency]
				,[DateOfJoining]
				,[FirstName]
				,[LastName]
				,[QualityAndRiskManagerId]
				,[QualityAndRiskManagerName]
				,[Roles]
				,[Supervisor]
				,[LandlinePhoneNumber]
				,[MobilePhoneNumber]
				,[ProtectionPanel]
				,[Status]
				,[RegionalBusinessConsultant]
				,[BusinessDevelopmentExecutive]
				,[RiskRating]
				,[DateOfBirth]
				,[Licenses]
				);

		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION;
	END CATCH;

	IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION;

	/***************************************************************************************************************************************************************************************************
	**	Clean up part 2
	***************************************************************************************************************************************************************************************************/
	DROP TABLE #BDHAdviser;
END
GO
/****** Object:  StoredProcedure [bdh].[AdviserDelta]    Script Date: 7/3/2026 3:25:19 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [bdh].[AdviserDelta]
@jsonData VARCHAR(MAX) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		BEGIN TRANSACTION;

		SET @jsonData = 
		(
			SELECT
					 [AdviserId]
					,[FirmId]
					,[AdviserEmail]
					,[AddressLine1] AS [Address.Line1]
					,[AddressLine2] AS [Address.Line2]
					,[AddressLine3] AS [Address.Line3]
					,[AddressLine4] AS [Address.Line4]
					,[AddressLine5] AS [Address.Line5]
					,[AddressPostalCode] AS [Address.PostalCode]
					,[Competency]
					,[DateOfJoining]
					,[FirstName]
					,[LastName]
					,[QualityAndRiskManagerId]
					,[QualityAndRiskManagerName]
					,[Roles]
					,[Supervisor]
					,[LandlinePhoneNumber]
					,[MobilePhoneNumber]
					,[ProtectionPanel]
					,[Status]
					,[RegionalBusinessConsultant]
					,[BusinessDevelopmentExecutive]
					,[RiskRating]
					,[DateOfBirth]
					,[Licenses]
			FROM	[bdh].[BDHAdviserDelta]
			WHERE	[DateDeltaUploaded] IS NULL
			ORDER BY [BDHAdviserDeltaId]
			FOR JSON PATH
		)

		UPDATE	[bdh].[BDHAdviserDelta]
		SET		[DateDeltaUploaded] = CAST( GETDATE() AS DATE )
		WHERE	[DateDeltaUploaded] IS NULL;

		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION;
	END CATCH;

	IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION;
END
GO
/****** Object:  StoredProcedure [bdh].[FirmData]    Script Date: 7/3/2026 3:25:19 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [bdh].[FirmData]
@jsonData VARCHAR(MAX) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;

	SET @jsonData = 
	(
		SELECT
				 [FirmId]
				,[EnterpriseName]
				,[LegalName]
				,[EmailAddress]
				,[DateOfJoining]
				,[MainPhoneNumber]
				,[AddressLine1] AS [Address.Line1]
				,[AddressLine2] AS [Address.Line2]
				,[AddressLine3] AS [Address.Line3]
				,[AddressLine4] AS [Address.Line4]
				,[AddressLine5] AS [Address.Line5]
				,[AddressPostalCode] AS [Address.PostalCode]
				,[EnhancementRatesCOB]
				,[EnhancementRatesMCOB]
				,[EnhancementRatesGI]
				,[EnhancementRatesICOBIP]
				,[EnhancementRatesICOBTerm]
				,[EnhancementRatesICOBWOL]
				,[FirmCompetency]
				,[ProtectionPanel]
				,[FirmStatus]
				,[RegionalBusinessConsultant]
				,[BusinessDevelopmentExecutive]
				,[RiskRating]
				,[FranchiseIndemnityArrangementCharge]
				,[RegulatorySupportCharge]
				,[Licenses]
		FROM	[bdh].[BDHFirm]
		ORDER BY [FirmId]
		FOR JSON PATH
	);
END
GO
/****** Object:  StoredProcedure [bdh].[FirmDataGeneration]    Script Date: 7/3/2026 3:25:19 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [bdh].[FirmDataGeneration]
AS
/******************************************************************************

Firm data extract for the Business Development Hub (also know as Adviser CRM)

*******************************************************************************/
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	IF OBJECT_ID('tempdb..#Owl') IS NOT NULL
		DROP TABLE #Owl;
	IF OBJECT_ID('tempdb..#BusinessArea') IS NOT NULL
		DROP TABLE #BusinessArea;
	IF OBJECT_ID('tempdb..#EnhancementRates') IS NOT NULL
		DROP TABLE #EnhancementRates;
	IF OBJECT_ID('tempdb..#ProtectionPanel') IS NOT NULL
		DROP TABLE #ProtectionPanel;
	IF OBJECT_ID('tempdb..#RiskRating') IS NOT NULL
		DROP TABLE #RiskRating;
	IF OBJECT_ID('tempdb..#Charges') IS NOT NULL
		DROP TABLE #Charges;
	IF OBJECT_ID('tempdb..#Licenses') IS NOT NULL
		DROP TABLE #Licenses;
	IF OBJECT_ID('tempdb..#BDHFirm') IS NOT NULL
		DROP TABLE #BDHFirm;

	CREATE TABLE #Owl
	(UserUID VARCHAR(7) NOT NULL
	);

	CREATE TABLE #BusinessArea
	([BusinessUID]	VARCHAR(7) NOT NULL
	,[BusinessArea]	VARCHAR(100) NOT NULL
	);

	CREATE TABLE #EnhancementRates
	([AgentCode]	VARCHAR(7) NOT NULL
	,[COB]			DECIMAL(10,2) NOT NULL
	,[MCOB]			DECIMAL(10,2) NOT NULL
	,[GI]			DECIMAL(10,2) NOT NULL
	,[ICOBIP]		DECIMAL(10,2) NOT NULL
	,[ICOBTerm]		DECIMAL(10,2) NOT NULL
	,[ICOBWOL]		DECIMAL(10,2) NOT NULL
	);

	CREATE TABLE #ProtectionPanel
	([BusinessUID]		VARCHAR(7) NOT NULL
	,[ProtectionPanel]	VARCHAR(100) NOT NULL
	,[RowNum]			BIGINT NOT NULL
	);

	CREATE TABLE #RiskRating
	([BusinessUID]	VARCHAR(7) NOT NULL
	,[RiskRating]	VARCHAR(100) NOT NULL
	);

	CREATE TABLE #Charges
	([AgentCode]	VARCHAR(7) NOT NULL
	,[FIA]			DECIMAL(9,2) NOT NULL
	,[RSC]			DECIMAL(9,2) NOT NULL
	);

	CREATE TABLE #Licenses
	([BusinessUID]	VARCHAR(7) NOT NULL
	,[Licenses]		VARCHAR(255) NOT NULL
	);

	CREATE TABLE #BDHFirm
	([FirmId]								VARCHAR(7) NOT NULL
	,[EnterpriseName]						VARCHAR(255) NOT NULL
	,[LegalName]							VARCHAR(255) NOT NULL
	,[EmailAddress]							VARCHAR(100) NOT NULL
	,[DateOfJoining]						DATE
	,[MainPhoneNumber]						VARCHAR(30) NOT NULL
	,[AddressLine1]							VARCHAR(35) NOT NULL
	,[AddressLine2]							VARCHAR(35) NOT NULL
	,[AddressLine3]							VARCHAR(35) NOT NULL
	,[AddressLine4]							VARCHAR(35) NOT NULL
	,[AddressLine5]							VARCHAR(35) NOT NULL
	,[AddressPostalCode]					VARCHAR(10) NOT NULL
	,[EnhancementRatesCOB]					DECIMAL(10,2) NOT NULL
	,[EnhancementRatesMCOB]					DECIMAL(10,2) NOT NULL
	,[EnhancementRatesGI]					DECIMAL(10,2) NOT NULL
	,[EnhancementRatesICOBIP]				DECIMAL(10,2) NOT NULL
	,[EnhancementRatesICOBTerm]				DECIMAL(10,2) NOT NULL
	,[EnhancementRatesICOBWOL]				DECIMAL(10,2) NOT NULL
	,[FirmCompetency]						VARCHAR(100) NOT NULL
	,[ProtectionPanel]						VARCHAR(100) NOT NULL
	,[FirmStatus]							VARCHAR(20) NOT NULL
	,[RegionalBusinessConsultant]			VARCHAR(7) NOT NULL
	,[BusinessDevelopmentExecutive]			VARCHAR(7) NOT NULL
	,[RiskRating]							VARCHAR(100) NOT NULL
	,[FranchiseIndemnityArrangementCharge]	DECIMAL(9,2) NOT NULL
	,[RegulatorySupportCharge]				DECIMAL(9,2) NOT NULL
	,[Licenses]								VARCHAR(255) NOT NULL
	);

	DECLARE  @Date			DATETIME
			,@Manager2Code	VARCHAR(7)
			;

	/***************************************************************************************************************************************************************************************************
	**	Owl
	***************************************************************************************************************************************************************************************************/
	SET  @Date = CAST( GETDATE() AS DATE );

	SELECT	@Manager2Code = cde.Code
	FROM	dbo.msit_MIWarehouseCodesAndDescriptions cde
	WHERE	cde.ColumnName = 'Manager2Code' 
	AND		cde.Description = 'Owl Financial';

	INSERT	#Owl 
			(UserUID
			)
	/* Insight */
	SELECT	CAST(ud.USR_ExternalID AS VARCHAR(7)) AS UserUID
	FROM		dbo.sa_insight_UserDetails ud
	INNER JOIN	dbo.sa_insight_UserPosition up	ON up.UPS_UserID = ud.USR_ID 
												AND ( up.UPS_DateTo IS NULL OR up.UPS_DateTo > @Date )
												AND ( up.UPS_JobTitle BETWEEN 51 AND 58 OR UP.UPS_JOBTITLE BETWEEN 61 AND 63 )
	WHERE	ud.USR_Name not like '%error%'
	AND		ud.USR_ExternalID IS NOT NULL
	AND		ud.USR_ExternalID <> ''
	UNION
	/* Swift */
	SELECT	 a.CODE AS UserUID
	FROM	dbo.mstt_Agents a
	WHERE	a.CompetentStatusDescription = 'Active' 
	AND		(	a.DESCN IN ('Pat McKenna', 'Owl Sales Director', 'OWL Area Sales Manager') 
			OR	a.Manager2Code = @Manager2Code
			);

	/***************************************************************************************************************************************************************************************************
	**	Business Area
	***************************************************************************************************************************************************************************************************/
	WITH BusinessArea AS
	(
	SELECT
		 uct.UC_OwnerID
		,CASE 
			WHEN cd.Code_Description = 'COB' AND uct2.UC_BusinessArea = 'MCOB' AND LEFT(cd5.Code_Description,4) = 'CF30'  THEN 'CMCOB' 
			WHEN cd.Code_Description = 'ICOB, MCOB and COB' THEN 'CMCOB' 
			WHEN cd.Code_Description = 'ICOB and COB' THEN 'COB' 
			WHEN cd.Code_Description = 'ICOB and MCOB' THEN 'MCOB' 
			WHEN cd.Code_Description = 'COB' AND LEFT(cd5.Code_Description,4) = 'CF30' THEN 'COB'  
			WHEN cd.Code_Description = 'COB' AND uct2.UC_BusinessArea <> 'MCOB' AND LEFT(cd5.Code_Description,4) <> 'CF30' THEN 'ICOB' 
			WHEN cd.Code_Description = 'COB' AND uct2.UC_BusinessArea = 'MCOB' AND LEFT(cd5.Code_Description,4) <> 'CF30'  THEN 'MCOB'  
			ELSE cd.Code_Description 
		 END AS BusinessArea
	FROM		(
				SELECT
					 uc.UC_OwnerID
					,MAX(uc.UC_BusinessArea) AS UC_BusinessArea
				FROM	dbo.sa_insight_UserCompetency AS uc
				WHERE	uc.UC_Status <> 1
				AND		uc.UC_BusinessArea < 9
				GROUP BY 
					 uc.UC_OwnerID
				)AS uct
	LEFT JOIN	(
				SELECT
					 uc.UC_OwnerID
					,'MCOB' AS UC_BusinessArea
				FROM	dbo.sa_insight_UserCompetency AS uc
				WHERE	uc.UC_Status <> 1
				AND		uc.UC_BusinessArea = 2
				GROUP BY 
					 uc.UC_OwnerID
				)AS uct2	ON uct2.UC_OwnerID = uct.UC_OwnerID
	LEFT JOIN	dbo.sa_insight_CodeDescription cd ON cd.Code_Code = uct.UC_BusinessArea AND cd.Code_CodeType = 534 
	LEFT JOIN	dbo.sa_insight_Staff s ON s.STAF_UserID = uct.UC_OwnerID
	LEFT JOIN	dbo.sa_insight_CodeDescription cd5 ON cd5.Code_Code = s.STAF_CustomerFunction AND cd5.Code_CodeType = 530 
	LEFT JOIN	dbo.sa_insight_UserPosition up ON up.UPS_UserID = uct.UC_OwnerID AND up.UPS_JobTitle = 3
	LEFT JOIN	dbo.sa_insight_UserPosition up2	ON up2.UPS_UserID = uct.UC_OwnerID 
													AND DATEADD(dd, 0, DATEDIFF(dd, 0, GETDATE())) BETWEEN up2.UPS_DateFrom AND ISNULL(up2.UPS_DateTo, 'Dec 31, 9999') 
													AND up2.UPS_JobTitle IN (4, 42) 
	WHERE	(	up.ups_id IS NOT NULL
			OR	up2.ups_id IS NOT NULL
			)
	)
	,AdviserBusinessArea AS
	(
	SELECT 
		 u.UserUID AS [AdviserId]
		,u.BusinessUID AS [FirmId]
		,COALESCE(	CASE 
						WHEN (	CASE 
									WHEN (LEFT(b.AgentCategoryDescription, 4) = 'NASP' 
									AND a.AgentCategoryDescription = 'Administrator') 
									THEN 'NASP' 
									ELSE b.AgentCategoryDescription 
								END) = 'NASP' 
						THEN 'NASP' 
						ELSE ba.BusinessArea 
					END,'') AS [BusinessArea]
	FROM		dbo.mi_insight_UserHierarchyAllUsers u
	LEFT JOIN	dbo.mstt_Agents a ON a.CODE = u.UserUID 
	LEFT JOIN	dbo.mstt_Agents b ON b.CODE = u.BusinessUID
	LEFT JOIN	BusinessArea ba ON  ba.UC_OwnerID = u.UserGUID
	WHERE	u.LatestRowInd = 1
	AND		NOT EXISTS ( SELECT * FROM #Owl o WHERE o.UserUID = u.UserUID ) 
	AND		u.BusinessUID IS NOT NULL 
	AND		u.UserContractStatus = 'Under Contract'
	)
	INSERT #BusinessArea
			([BusinessUID]
			,[BusinessArea]
			)
	SELECT	 FirmId
			,CASE 
				WHEN SUM( CASE WHEN BusinessArea IN ('COB', 'CMCOB', 'MCOB') THEN 1 ELSE 0 END ) = 0 THEN 'ICOB'
				WHEN SUM( CASE WHEN BusinessArea IN ('COB', 'CMCOB') THEN 1 ELSE 0 END ) = 0 THEN 'MCOB'
				WHEN SUM( CASE WHEN BusinessArea = 'CMCOB' THEN 1 ELSE 0 END ) > 0 THEN 'CMCOB'
				WHEN SUM( CASE WHEN BusinessArea = 'MCOB' THEN 1 ELSE 0 END ) > 0
				AND SUM( CASE WHEN BusinessArea = 'COB' THEN 1 ELSE 0 END ) > 0 THEN 'CMCOB'
				ELSE 'COB'
			 END AS FirmBusinessArea
	FROM AdviserBusinessArea
	GROUP BY FirmId;

	/***************************************************************************************************************************************************************************************************
	**	Enhancement Rates
	***************************************************************************************************************************************************************************************************/
	INSERT	#EnhancementRates
		([AgentCode]
		,[COB]
		,[MCOB]
		,[GI]
		,[ICOBIP]
		,[ICOBTerm]
		,[ICOBWOL]
		)
	SELECT 
		 AgentCode 
		,CAST( MAX( CASE WHEN ProductCode = 'OZISA' THEN UpliftRate-20 ELSE 0 END ) AS DECIMAL(10,2) ) AS [COB]
		,CAST( MAX( CASE WHEN ProductCode = 'NWIDE' THEN UpliftRate-20 ELSE 0 END ) AS DECIMAL(10,2) ) AS [MCOB]
		,CAST( MAX( CASE WHEN ProductCode = 'UKPLC' THEN UpliftRate-75 ELSE 0 END ) AS DECIMAL(10,2) ) AS [GI]
		,CAST( MAX( CASE WHEN ProductCode = 'IPP' THEN UpliftRate ELSE 0 END ) AS DECIMAL(10,2) ) AS [ICOBIP]
		,CAST( MAX( CASE WHEN ProductCode = 'LPP' THEN UpliftRate ELSE 0 END ) AS DECIMAL(10,2) ) AS [ICOBTerm]
		,CAST( MAX( CASE WHEN ProductCode = 'ZALP' THEN UpliftRate ELSE 0 END ) AS DECIMAL(10,2) ) AS [ICOBWOL]
	FROM	dbo.sa_swift_AgentUplifts au
	JOIN	dbo.mstt_agents a	 ON a.CODE = au.AgentCode 
								AND a.CompetentStatusDescription = 'Active' 
								AND ISNULL(a.Manager2Code,'111') != '1011671'
	WHERE	au.DateInForce =	(
								SELECT	MAX(au2.DateInForce)
								FROM	dbo.sa_swift_AgentUplifts au2
								WHERE	au.AgentCode = au2.AgentCode
								AND		au2.ProductCode = au.productcode
								)
	AND		au.ProductCode in ('LPP','ZALP','IPP','NWIDE','UKPLC','OZISA')
	GROUP BY au.AgentCode;

	/***************************************************************************************************************************************************************************************************
	**	Protection Panel
	***************************************************************************************************************************************************************************************************/
	INSERT	#ProtectionPanel
		([BusinessUID]
		,[ProtectionPanel]
		,[RowNum]
		)
	SELECT
		 u.BusinessUID
		,pp.ProtectionPanel
		,ROW_NUMBER() OVER ( PARTITION BY u.BusinessUID ORDER BY pp.ProtectionPanel ) AS RowNum
	FROM	dbo.mi_insight_UserHierarchyAllUsers u
	JOIN	(
			SELECT	 up.UPS_UserID
					,CASE 
						WHEN cd.Code_Description = '001 - Zurich Plus'					THEN '001 - Zurich Plus' 
						WHEN cd.Code_Description = '005 - Openwork Select'				THEN '005 - Openwork Select' 
						WHEN cd.Code_Description = '007 - Pension Panel Zurich Plus'	THEN '001 - Zurich Plus' 
						WHEN cd.Code_Description = '008 - Pension Panel Select'			THEN '005 - Openwork Select' 
						WHEN cd.Code_Description = '032 - Legal and General Single Tie'	THEN '032 - Legal and General Single Tie' 
						ELSE ''
					 END AS [ProtectionPanel]
					,ROW_NUMBER() OVER (PARTITION BY up.UPS_UserID ORDER BY up.UPS_UpdatedDate DESC) AS RowNum
			FROM	dbo.sa_insight_UserPosition up
			JOIN	dbo.sa_insight_CodeDescription cd ON cd.Code_Code = up.UPS_Section AND cd.Code_CodeType = 53
			WHERE	ups_UserType = 3    --Adviser/Seller
			) AS  pp ON pp.UPS_UserID = u.UserGUID
					AND pp.ProtectionPanel <> ''
					AND pp.RowNum = 1
	WHERE	u.LatestRowInd = 1 
	AND		u.BusinessUID IS NOT NULL 
	AND		u.UserContractStatus = 'Under Contract'
	AND		NOT EXISTS ( SELECT * FROM #Owl o WHERE o.UserUID = u.UserUID ) 
	GROUP BY u.BusinessUID
			,pp.ProtectionPanel
			;

	WITH MultiPP AS
	(
	SELECT pp1.BusinessUID,
		   STUFF(	(	SELECT ';' + rtrim(convert(VARCHAR(100),pp2.ProtectionPanel))
						FROM   #ProtectionPanel AS pp2
						WHERE  pp2.BusinessUID = pp1.BusinessUID
						FOR XML PATH('')
					),1,1,'') ProtectionPanel
	FROM   #ProtectionPanel AS pp1
	WHERE	pp1.RowNum > 1
	GROUP BY pp1.BusinessUID
	)
	UPDATE	pp
	SET		pp.ProtectionPanel = mpp.ProtectionPanel
	FROM	#ProtectionPanel pp
	JOIN	MultiPP mpp ON mpp.BusinessUID = pp.BusinessUID
	WHERE	pp.RowNum = 1;

	DELETE	#ProtectionPanel
	WHERE	RowNum > 1;

	/***************************************************************************************************************************************************************************************************
	**	Risk Rating
	***************************************************************************************************************************************************************************************************/
	WITH RiskRating AS
	(
	SELECT
		 uh.BusinessUID
		,CASE cd.Code_Description
			WHEN 'Green' THEN 'Green'
			WHEN 'Amber' THEN 'Amber'
			WHEN 'Red' THEN 'Red'
			WHEN 'Red Flag' THEN 'Red'
			ELSE ''
			END AS [RiskRating]
		,ROW_NUMBER() OVER( PARTITION BY uh.BusinessUID ORDER BY ra.RA_Date DESC ) AS RowNum
	FROM dbo.sa_insight_RiskAssessment ra
	JOIN dbo.sa_insight_CodeDescription cd ON cd.Code_Code = ra.RA_Status and cd.Code_CodeType = 500
	JOIN dbo.mi_insight_UserHierarchy uh ON uh.BusinessGUID = RA_USR_ID
	WHERE ra.RA_Date > DATEADD(YEAR,-1,GETDATE())
	GROUP BY uh.BusinessUID
			,CASE cd.Code_Description
				WHEN 'Green' THEN 'Green'
				WHEN 'Amber' THEN 'Amber'
				WHEN 'Red' THEN 'Red'
				WHEN 'Red Flag' THEN 'Red'
				ELSE ''
				END
			,ra.RA_Date
	)
	INSERT	#RiskRating
		([BusinessUID]
		,[RiskRating]
		)
	SELECT	
		 r.BusinessUID
		,r.RiskRating
	FROM	RiskRating r
	WHERE	r.RowNum = 1;

	/***************************************************************************************************************************************************************************************************
	**	FIA = Franchise Indemnity Arrangement charge
	**	RSC = Regulatory Support Charge
	***************************************************************************************************************************************************************************************************/
	SET  @Date = CAST( DATEADD( DAY, -60, GETDATE() ) AS DATE );

	WITH Charges AS 
	(
	SELECT
		 so.AgentCode
		,so.StandingOrderCode
		,ABS(so.PaymentAmount) AS Amount
		,ROW_NUMBER() OVER ( PARTITION BY so.AgentCode, so.StandingOrderCode ORDER BY so.ID DESC ) AS RowNum
	FROM	dbo.sa_swift_CommAgentStandingOrders so
	WHERE	so.StandingOrderCode IN ('0000002', '0000066')
	AND		so.EndDate > @Date
	)
	INSERT #Charges
			([AgentCode]
			,[FIA]
			,[RSC]
			)
	SELECT	 c.AgentCode
			,SUM(CASE WHEN c.StandingOrderCode = '0000002' THEN c.Amount ELSE 0.0 END) AS FIA
			,SUM(CASE WHEN c.StandingOrderCode = '0000066' THEN c.Amount ELSE 0.0 END) AS RSC
	FROM	Charges c
	WHERE	c.RowNum = 1
	GROUP BY c.AgentCode;

	/***************************************************************************************************************************************************************************************************
	**	License
	***************************************************************************************************************************************************************************************************/
	WITH License AS 
	(
	SELECT DISTINCT
		 u.BusinessUID
		,l.LIC_Description AS [License]
	FROM		dbo.mi_insight_UserHierarchyAllUsers u
	INNER JOIN	dbo.sa_insight_UserLicence ul	ON ul.ULIC_UserID = u.UserGUID
												AND	UL.ULIC_Status = 2
	INNER JOIN	dbo.sa_insight_Licence l	ON l.LIC_ID = ul.ULIC_LicenceID
											AND	L.LIC_Code IN	(N'LIC130'
																,N'LIC135'
																,N'LIC030'
																,N'LIC78'
																,N'LIC70'
																,N'LIC69'
																,N'LIC134'
																)
	WHERE	u.LatestRowInd = 1 
	AND		u.BusinessUID IS NOT NULL 
	AND		u.UserContractStatus = 'Under Contract'
	AND		NOT EXISTS ( SELECT * FROM #Owl o WHERE o.UserUID = u.UserUID ) 
	GROUP BY 
		 u.BusinessUID
		,l.LIC_Description
	)
	INSERT #Licenses
		([BusinessUID]
		,[Licenses]
		)
	SELECT l1.BusinessUID,
		   STUFF(	(	SELECT '; ' + RTRIM(CONVERT(VARCHAR(255),l2.License))
						FROM   License AS l2
						WHERE  l2.BusinessUID = l1.BusinessUID
						FOR XML PATH('')
					),1,1,'') AS Licenses
	FROM   License AS l1
	GROUP BY l1.BusinessUID;

	/***************************************************************************************************************************************************************************************************
	**	BDH Firm Data
	***************************************************************************************************************************************************************************************************/
	INSERT #BDHFirm
		([FirmId]
		,[EnterpriseName]
		,[LegalName]
		,[EmailAddress]
		,[DateOfJoining]
		,[MainPhoneNumber]
		,[AddressLine1]
		,[AddressLine2]
		,[AddressLine3]
		,[AddressLine4]
		,[AddressLine5]
		,[AddressPostalCode]
		,[EnhancementRatesCOB]
		,[EnhancementRatesMCOB]
		,[EnhancementRatesGI]
		,[EnhancementRatesICOBIP]
		,[EnhancementRatesICOBTerm]
		,[EnhancementRatesICOBWOL]
		,[FirmCompetency]
		,[ProtectionPanel]
		,[FirmStatus]
		,[RegionalBusinessConsultant]
		,[BusinessDevelopmentExecutive]
		,[RiskRating]
		,[FranchiseIndemnityArrangementCharge]
		,[RegulatorySupportCharge]
		,[Licenses]
		)
	SELECT
		 ISNULL(LTRIM(RTRIM(a.CODE)), '') AS [FirmId] 
		,LTRIM(RTRIM(COALESCE(a.TradingName, a.DESCN, ''))) AS [EnterpriseName]
		,ISNULL(LTRIM(RTRIM(a.DESCN)), '') AS [LegalName]
		,ISNULL(LTRIM(RTRIM(CASE WHEN ISNULL(a.EMAIL, '') = '' THEN c.EMAIL ELSE a.EMAIL END)), '') AS [EmailAddress]
		,CAST(ISNULL(a.OscarDateStarted , a.dateStarted) AS DATE) AS [DateOfJoining]
		,ISNULL(LTRIM(RTRIM(a.TELEPHONE)), '') AS [MainPhoneNumber]
		,ISNULL(LTRIM(RTRIM(a.Address1)),'') AS [Address.Line1]
		,ISNULL(LTRIM(RTRIM(a.Address2)),'') AS [Address.Line2]
		,ISNULL(LTRIM(RTRIM(a.Address3)),'') AS [Address.Line3]
		,ISNULL(LTRIM(RTRIM(a.Address4)),'') AS [Address.Line4]
		,ISNULL(LTRIM(RTRIM(a.Address5)),'') AS [Address.Line5]
		,ISNULL(LTRIM(RTRIM(a.Postcode)),'') AS [Address.PostalCode]
		,ISNULL(er.COB, 0) AS [EnhancementRatesCOB]
		,ISNULL(er.MCOB, 0) AS [EnhancementRatesMCOB]
		,ISNULL(er.GI, 0) AS [EnhancementRatesGI]
		,ISNULL(er.ICOBIP, 0) AS [EnhancementRatesICOBIP]
		,ISNULL(er.ICOBTerm, 0) AS [EnhancementRatesICOBTerm]
		,ISNULL(er.ICOBWOL, 0) AS [EnhancementRatesICOBWOL]
		,ISNULL(LTRIM(RTRIM(ba.BusinessArea)), '') AS [FirmCompetency]
		,ISNULL(LTRIM(RTRIM(pp.ProtectionPanel)), '') AS [ProtectionPanel]
		,CASE 
			WHEN a.CODE = '1002505' THEN 'Left' 
			WHEN a.CODE = '1001364' THEN 'Left' 
			WHEN a.EMAIL LIKE '%Deceased%' AND a.AgentType = 43 THEN 'Left' 
			ELSE a.CompetentStatusdescription 
		 END AS [FirmStatus]
		,ISNULL(a.Manager3Code, '') AS [RegionalBusinessConsultant]
		,ISNULL(a.Manager2Code, '') AS [BusinessDevelopmentExecutive]
		,ISNULL(rr.RiskRating, '') AS [RiskRating]
		,ISNULL(ch.FIA, 0.0) AS [FranchiseIndemnityArrangementCharge]
		,ISNULL(ch.RSC, 0.0) AS [RegulatorySupportCharge]
		,ISNULL(l.Licenses, '') AS [Licenses]
	FROM		dbo.mstt_Agents a
	LEFT JOIN	dbo.mstt_Clients c ON c.AgentCode = a.CODE
	LEFT JOIN	#BusinessArea ba ON ba.BusinessUID = a.CODE
	LEFT JOIN	#EnhancementRates er ON er.AgentCode = a.CODE
	LEFT JOIN	#ProtectionPanel pp ON pp.BusinessUID = a.CODE
	LEFT JOIN	#RiskRating rr ON rr.BusinessUID = a.CODE
	LEFT JOIN	#Charges ch ON  ch.AgentCode = a.CODE
	LEFT JOIN	#Licenses l ON  l.BusinessUID = a.CODE
	WHERE	a.CODE NOT IN ('1005260', '2001539','1011607','1011608','1011609','2001815', '2004327') 
	AND		a.AgentTypeDescription = 'Franchise'
	AND		a.CompetentStatusdescription = 'Active'
	AND		NOT EXISTS ( SELECT * FROM #Owl o WHERE o.UserUID = a.CODE );

	/***************************************************************************************************************************************************************************************************
	**	Clean up part 1
	***************************************************************************************************************************************************************************************************/
	DROP TABLE #Owl;
	DROP TABLE #BusinessArea;
	DROP TABLE #EnhancementRates;
	DROP TABLE #ProtectionPanel;
	DROP TABLE #RiskRating;
	DROP TABLE #Charges;
	DROP TABLE #Licenses;

	/***************************************************************************************************************************************************************************************************
	**	Refresh the Firm data set
	***************************************************************************************************************************************************************************************************/
	BEGIN TRY
		BEGIN TRANSACTION

		/***************************************************************************************************************************************************************************************************
		**	Remove old Firm deltas
		***************************************************************************************************************************************************************************************************/
		SET  @Date = CAST( DATEADD( DAY, -7, GETDATE() ) AS DATE );

		DELETE	bdh.BDHFirmDelta
		WHERE	[DateDeltaUploaded] < @Date;

		/***************************************************************************************************************************************************************************************************
		**	Remove missing Firm entries
		***************************************************************************************************************************************************************************************************/
		DELETE	bdh.BDHFirm
		OUTPUT	
				 deleted.[FirmId]
				,deleted.[EnterpriseName]
				,deleted.[LegalName]
				,deleted.[EmailAddress]
				,deleted.[DateOfJoining]
				,deleted.[MainPhoneNumber]
				,deleted.[AddressLine1]
				,deleted.[AddressLine2]
				,deleted.[AddressLine3]
				,deleted.[AddressLine4]
				,deleted.[AddressLine5]
				,deleted.[AddressPostalCode]
				,deleted.[EnhancementRatesCOB]
				,deleted.[EnhancementRatesMCOB]
				,deleted.[EnhancementRatesGI]
				,deleted.[EnhancementRatesICOBIP]
				,deleted.[EnhancementRatesICOBTerm]
				,deleted.[EnhancementRatesICOBWOL]
				,deleted.[FirmCompetency]
				,deleted.[ProtectionPanel]
				,'Inactive'
				,deleted.[RegionalBusinessConsultant]
				,deleted.[BusinessDevelopmentExecutive]
				,deleted.[RiskRating]
				,deleted.[FranchiseIndemnityArrangementCharge]
				,deleted.[RegulatorySupportCharge]
				,deleted.[Licenses]
		INTO	bdh.BDHFirmDelta
				([FirmId]
				,[EnterpriseName]
				,[LegalName]
				,[EmailAddress]
				,[DateOfJoining]
				,[MainPhoneNumber]
				,[AddressLine1]
				,[AddressLine2]
				,[AddressLine3]
				,[AddressLine4]
				,[AddressLine5]
				,[AddressPostalCode]
				,[EnhancementRatesCOB]
				,[EnhancementRatesMCOB]
				,[EnhancementRatesGI]
				,[EnhancementRatesICOBIP]
				,[EnhancementRatesICOBTerm]
				,[EnhancementRatesICOBWOL]
				,[FirmCompetency]
				,[ProtectionPanel]
				,[FirmStatus]
				,[RegionalBusinessConsultant]
				,[BusinessDevelopmentExecutive]
				,[RiskRating]
				,[FranchiseIndemnityArrangementCharge]
				,[RegulatorySupportCharge]
				,[Licenses]
				)
		WHERE	[FirmId] NOT IN ( SELECT [FirmId] FROM #BDHFirm );

		/***************************************************************************************************************************************************************************************************
		**	Create new and update existing Firms
		***************************************************************************************************************************************************************************************************/
		WITH InsUpd AS
				(
				SELECT
						 [FirmId]
						,[EnterpriseName]
						,[LegalName]
						,[EmailAddress]
						,[DateOfJoining]
						,[MainPhoneNumber]
						,[AddressLine1]
						,[AddressLine2]
						,[AddressLine3]
						,[AddressLine4]
						,[AddressLine5]
						,[AddressPostalCode]
						,[EnhancementRatesCOB]
						,[EnhancementRatesMCOB]
						,[EnhancementRatesGI]
						,[EnhancementRatesICOBIP]
						,[EnhancementRatesICOBTerm]
						,[EnhancementRatesICOBWOL]
						,[FirmCompetency]
						,[ProtectionPanel]
						,[FirmStatus]
						,[RegionalBusinessConsultant]
						,[BusinessDevelopmentExecutive]
						,[RiskRating]
						,[FranchiseIndemnityArrangementCharge]
						,[RegulatorySupportCharge]
						,[Licenses]
				FROM	#BDHFirm
				EXCEPT
				SELECT
						 [FirmId]
						,[EnterpriseName]
						,[LegalName]
						,[EmailAddress]
						,[DateOfJoining]
						,[MainPhoneNumber]
						,[AddressLine1]
						,[AddressLine2]
						,[AddressLine3]
						,[AddressLine4]
						,[AddressLine5]
						,[AddressPostalCode]
						,[EnhancementRatesCOB]
						,[EnhancementRatesMCOB]
						,[EnhancementRatesGI]
						,[EnhancementRatesICOBIP]
						,[EnhancementRatesICOBTerm]
						,[EnhancementRatesICOBWOL]
						,[FirmCompetency]
						,[ProtectionPanel]
						,[FirmStatus]
						,[RegionalBusinessConsultant]
						,[BusinessDevelopmentExecutive]
						,[RiskRating]
						,[FranchiseIndemnityArrangementCharge]
						,[RegulatorySupportCharge]
						,[Licenses]
				FROM	bdh.BDHFirm
				)
		MERGE bdh.BDHFirm AS prev
		USING InsUpd AS curr
			ON curr.[FirmId] = prev.[FirmId]
		WHEN MATCHED
			THEN
				UPDATE SET
						 [EnterpriseName]						= curr.[EnterpriseName]
						,[LegalName]							= curr.[LegalName]
						,[EmailAddress]							= curr.[EmailAddress]
						,[DateOfJoining]						= curr.[DateOfJoining]
						,[MainPhoneNumber]						= curr.[MainPhoneNumber]
						,[AddressLine1]							= curr.[AddressLine1]
						,[AddressLine2]							= curr.[AddressLine2]
						,[AddressLine3]							= curr.[AddressLine3]
						,[AddressLine4]							= curr.[AddressLine4]
						,[AddressLine5]							= curr.[AddressLine5]
						,[AddressPostalCode]					= curr.[AddressPostalCode]
						,[EnhancementRatesCOB]					= curr.[EnhancementRatesCOB]
						,[EnhancementRatesMCOB]					= curr.[EnhancementRatesMCOB]
						,[EnhancementRatesGI]					= curr.[EnhancementRatesGI]
						,[EnhancementRatesICOBIP]				= curr.[EnhancementRatesICOBIP]
						,[EnhancementRatesICOBTerm]				= curr.[EnhancementRatesICOBTerm]
						,[EnhancementRatesICOBWOL]				= curr.[EnhancementRatesICOBWOL]
						,[FirmCompetency]						= curr.[FirmCompetency]
						,[ProtectionPanel]						= curr.[ProtectionPanel]
						,[FirmStatus]							= curr.[FirmStatus]
						,[RegionalBusinessConsultant]			= curr.[RegionalBusinessConsultant]
						,[BusinessDevelopmentExecutive]			= curr.[BusinessDevelopmentExecutive]
						,[RiskRating]							= curr.[RiskRating]
						,[FranchiseIndemnityArrangementCharge]	= curr.[FranchiseIndemnityArrangementCharge]
						,[RegulatorySupportCharge]				= curr.[RegulatorySupportCharge]
						,[Licenses]								= curr.[Licenses]
		WHEN NOT MATCHED BY TARGET
			THEN
				INSERT	([FirmId]
						,[EnterpriseName]
						,[LegalName]
						,[EmailAddress]
						,[DateOfJoining]
						,[MainPhoneNumber]
						,[AddressLine1]
						,[AddressLine2]
						,[AddressLine3]
						,[AddressLine4]
						,[AddressLine5]
						,[AddressPostalCode]
						,[EnhancementRatesCOB]
						,[EnhancementRatesMCOB]
						,[EnhancementRatesGI]
						,[EnhancementRatesICOBIP]
						,[EnhancementRatesICOBTerm]
						,[EnhancementRatesICOBWOL]
						,[FirmCompetency]
						,[ProtectionPanel]
						,[FirmStatus]
						,[RegionalBusinessConsultant]
						,[BusinessDevelopmentExecutive]
						,[RiskRating]
						,[FranchiseIndemnityArrangementCharge]
						,[RegulatorySupportCharge]
						,[Licenses]
						)
				VALUES	(curr.[FirmId]
						,curr.[EnterpriseName]
						,curr.[LegalName]
						,curr.[EmailAddress]
						,curr.[DateOfJoining]
						,curr.[MainPhoneNumber]
						,curr.[AddressLine1]
						,curr.[AddressLine2]
						,curr.[AddressLine3]
						,curr.[AddressLine4]
						,curr.[AddressLine5]
						,curr.[AddressPostalCode]
						,curr.[EnhancementRatesCOB]
						,curr.[EnhancementRatesMCOB]
						,curr.[EnhancementRatesGI]
						,curr.[EnhancementRatesICOBIP]
						,curr.[EnhancementRatesICOBTerm]
						,curr.[EnhancementRatesICOBWOL]
						,curr.[FirmCompetency]
						,curr.[ProtectionPanel]
						,curr.[FirmStatus]
						,curr.[RegionalBusinessConsultant]
						,curr.[BusinessDevelopmentExecutive]
						,curr.[RiskRating]
						,curr.[FranchiseIndemnityArrangementCharge]
						,curr.[RegulatorySupportCharge]
						,curr.[Licenses]
						)
		OUTPUT	
				 inserted.[FirmId]
				,inserted.[EnterpriseName]
				,inserted.[LegalName]
				,inserted.[EmailAddress]
				,inserted.[DateOfJoining]
				,inserted.[MainPhoneNumber]
				,inserted.[AddressLine1]
				,inserted.[AddressLine2]
				,inserted.[AddressLine3]
				,inserted.[AddressLine4]
				,inserted.[AddressLine5]
				,inserted.[AddressPostalCode]
				,inserted.[EnhancementRatesCOB]
				,inserted.[EnhancementRatesMCOB]
				,inserted.[EnhancementRatesGI]
				,inserted.[EnhancementRatesICOBIP]
				,inserted.[EnhancementRatesICOBTerm]
				,inserted.[EnhancementRatesICOBWOL]
				,inserted.[FirmCompetency]
				,inserted.[ProtectionPanel]
				,inserted.[FirmStatus]
				,inserted.[RegionalBusinessConsultant]
				,inserted.[BusinessDevelopmentExecutive]
				,inserted.[RiskRating]
				,inserted.[FranchiseIndemnityArrangementCharge]
				,inserted.[RegulatorySupportCharge]
				,inserted.[Licenses]
		INTO	bdh.BDHFirmDelta
				([FirmId]
				,[EnterpriseName]
				,[LegalName]
				,[EmailAddress]
				,[DateOfJoining]
				,[MainPhoneNumber]
				,[AddressLine1]
				,[AddressLine2]
				,[AddressLine3]
				,[AddressLine4]
				,[AddressLine5]
				,[AddressPostalCode]
				,[EnhancementRatesCOB]
				,[EnhancementRatesMCOB]
				,[EnhancementRatesGI]
				,[EnhancementRatesICOBIP]
				,[EnhancementRatesICOBTerm]
				,[EnhancementRatesICOBWOL]
				,[FirmCompetency]
				,[ProtectionPanel]
				,[FirmStatus]
				,[RegionalBusinessConsultant]
				,[BusinessDevelopmentExecutive]
				,[RiskRating]
				,[FranchiseIndemnityArrangementCharge]
				,[RegulatorySupportCharge]
				,[Licenses]
				);

		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION;
	END CATCH;

	IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION;

	/***************************************************************************************************************************************************************************************************
	**	Clean up part 2
	***************************************************************************************************************************************************************************************************/
	DROP TABLE #BDHFirm;
END
GO
/****** Object:  StoredProcedure [bdh].[FirmDelta]    Script Date: 7/3/2026 3:25:19 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

CREATE   PROCEDURE [bdh].[FirmDelta]
@jsonData VARCHAR(MAX) OUTPUT
AS
BEGIN
	SET NOCOUNT ON;
	SET XACT_ABORT ON;

	BEGIN TRY
		BEGIN TRANSACTION;

		SET @jsonData = 
		(
			SELECT
					 [FirmId]
					,[EnterpriseName]
					,[LegalName]
					,[EmailAddress]
					,[DateOfJoining]
					,[MainPhoneNumber]
					,[AddressLine1] AS [Address.Line1]
					,[AddressLine2] AS [Address.Line2]
					,[AddressLine3] AS [Address.Line3]
					,[AddressLine4] AS [Address.Line4]
					,[AddressLine5] AS [Address.Line5]
					,[AddressPostalCode] AS [Address.PostalCode]
					,[EnhancementRatesCOB]
					,[EnhancementRatesMCOB]
					,[EnhancementRatesGI]
					,[EnhancementRatesICOBIP]
					,[EnhancementRatesICOBTerm]
					,[EnhancementRatesICOBWOL]
					,[FirmCompetency]
					,[ProtectionPanel]
					,[FirmStatus]
					,[RegionalBusinessConsultant]
					,[BusinessDevelopmentExecutive]
					,[RiskRating]
					,[FranchiseIndemnityArrangementCharge]
					,[RegulatorySupportCharge]
					,[Licenses]
			FROM	[bdh].[BDHFirmDelta]
			WHERE	[DateDeltaUploaded] IS NULL
			ORDER BY [BDHFirmDeltaId]
			FOR JSON PATH
		);

		UPDATE	[bdh].[BDHFirmDelta]
		SET		[DateDeltaUploaded] = CAST( GETDATE() AS DATE )
		WHERE	[DateDeltaUploaded] IS NULL;

		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		ROLLBACK TRANSACTION;
	END CATCH;

	IF @@TRANCOUNT > 0
		ROLLBACK TRANSACTION;
END
GO
