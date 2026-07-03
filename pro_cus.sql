GO
/****** Object:  StoredProcedure [CustomerOutcomes].[pr_etl_AIT_AdviserInvestigation]    Script Date: 7/3/2026 3:44:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/************************************************************************************************
  	 Program:  	pr_etl_AIT_AdviserInvestigation
	  Author:	A Groves
Date created:	24/11/2016

		Type:	Customer Outcomes
		
 Description:   This proc populates table "CustomerOutcomes.owt_AIT_AdviserInvestigation"
				from the staging table "CustomerOutcomes.sa_AIT_AdviserInvestigation" that 
				was loaded by SSIS script "CustomerOutcomesAITToStaging32Bit.dtsx".

		Note:	The spreadsheet contains a "DO NOT DELETE" row which was put in to force 
				the SSIS Excel driver to treat every column as characters. Without this,
				the Excel driver incorrectly guesses some columns are numeric and if they
				actually contain characters, then these aren't loaded.

				It is called as follows:

				exec CustomerOutcomes.pr_etl_AIT_AdviserInvestigation 'Openwork', 'CustomerOutcomes'
									
Amendment History								
-----------------								
											
Date		Who			Description				
----		---			-----------
09/01/2017	A Groves	Re-written to MERGE the data rather than empty-and-load, in case the
						spreadsheet owner decides to empty out the old data, then the old data
						will not be lost in the table.	
05/04/2017	A Groves	Case numbers appear to be pre-allocated, so exclude any rows where, in 
						addition to the CaseNumber being blank, so also must the DateInDepartment 
						be blank. 
************************************************************************************************/
CREATE PROCEDURE [CustomerOutcomes].[pr_etl_AIT_AdviserInvestigation] 
	@Client		varchar(50),
	@Module		varchar(50)
as

set nocount on
set xact_abort on	-- Ensures all SQL statements are rolled back in the event of an error.

declare @PhaseStart					varchar(50),
		@PhaseEnd					varchar(50),
		@PhaseLog					varchar(50),
		@PhaseError					varchar(50),
		@Process					varchar(100),
		@ProcessMessage				varchar(100),
		@RowCount					int,
		@ErrMsg						varchar(400),
		@ErrMsgBrief				varchar(100), 
		@Severity 					int,
		@DateLastUpdated			datetime
		
/****************************************************************************

	Set initial parameters																
																		
****************************************************************************/

set @PhaseStart					= 'START'
set @PhaseEnd   				= 'END'
set @PhaseLog					= 'LOG'
set @PhaseError					= 'ERROR'
set @Process					= object_name(@@procid)
set @DateLastUpdated			= getdate()

/****************************************************************************

	Log start - we want this whether or not a rollback occurs
																		
****************************************************************************/

exec msp_ProcessLog @PhaseStart, @Process, null, @Module, @Client

/****************************************************************************

	Processing start - beyond this point everything should be capable of rollback
																		
****************************************************************************/

BEGIN TRY

	/****************************************************************************

		Start transaction
																			
	****************************************************************************/

	BEGIN TRANSACTION
	
	/****************************************************************************
	
		Insert rows into the destination table

	****************************************************************************/

	select top 0 * into #AIT from CustomerOutcomes.owt_AIT_AdviserInvestigation

	insert into #AIT
	(
		CaseNumber,
		DateInDepartment,
		ProductType,
		Category,
		FCAReportable,
		Status,
		Outcome,
		DateClosed,
		JustifiedAgainstAdviser
	)
	select	CaseNumber,
			case isdate(DateInDepartment)
				when 1 then DateInDepartment
				else null
			end as DateInDepartment,
			ProductType,
			Category,
			FCAReportable,
			Status,
			Outcome,
			case isdate(DateClosed)
				when 1 then DateClosed
				else null
			end as DateClosed,
			JustifiedAgainstAdviser
	from	CustomerOutcomes.sa_AIT_AdviserInvestigation
	where	isnull(CaseNumber,'') <> ''
	and		isnull(DateInDepartment,'') <> ''				-- AG 05/04/2017
	and		CaseNumber not like '%[A-Z][A-Z][A-Z][A-Z]%'	-- Excludes the	"DO NOT DELETE" row.
	
	/****************************************************************************
	
		Merge rows into the destination table

	****************************************************************************/

	merge	CustomerOutcomes.owt_AIT_AdviserInvestigation as target
	using	#AIT as source
	on		target.CaseNumber = source.CaseNumber 
	when	matched 
			and (isnull(target.DateInDepartment,'') <> isnull(source.DateInDepartment,'')
			or	 isnull(target.ProductType,'') <> isnull(source.ProductType,'')
			or	 isnull(target.Category,'') <> isnull(source.Category,'')
			or	 isnull(target.FCAReportable,'') <> isnull(source.FCAReportable,'')
			or	 isnull(target.Status,'') <> isnull(source.Status,'')
			or	 isnull(target.Outcome,'') <> isnull(source.Outcome,'')
			or	 isnull(target.DateClosed,'') <> isnull(source.DateClosed,'')
			or	 isnull(target.JustifiedAgainstAdviser,'') <> isnull(source.JustifiedAgainstAdviser,''))
	then	update 
				set target.CaseNumber = source.CaseNumber,
					target.DateInDepartment = source.DateInDepartment,
					target.ProductType = source.ProductType,
					target.Category = source.Category,
					target.FCAReportable = source.FCAReportable,
					target.Status = source.Status,
					target.Outcome = source.Outcome,
					target.DateClosed = source.DateClosed,
					target.JustifiedAgainstAdviser = source.JustifiedAgainstAdviser,
					target.DateLastUpdated = @DateLastUpdated
	when	not matched by target
	then	insert
			(
				CaseNumber,
				DateInDepartment,
				ProductType,
				Category,
				FCAReportable,
				Status,
				Outcome,
				DateClosed,
				JustifiedAgainstAdviser,
				DateInserted,
				DateLastUpdated
			)		
			values
			(
				CaseNumber,
				DateInDepartment,
				ProductType,
				Category,
				FCAReportable,
				Status,
				Outcome,
				DateClosed,
				JustifiedAgainstAdviser,
				@DateLastUpdated,
				@DateLastUpdated
			);

	/****************************************************************************

		Processing end
																		
	****************************************************************************/

	exec msp_ProcessLog @PhaseEnd, @Process, null, @Module, @Client

	/****************************************************************************

		End transaction
																			
	****************************************************************************/

	COMMIT TRANSACTION   

END TRY

BEGIN CATCH 

	IF @@TRANCOUNT <> 0
		ROLLBACK TRANSACTION
		
	SET @ErrMsg = @Process + ' failed.' + REPLACE(ERROR_MESSAGE(), '.', '') + ' (error no: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ') on line ' + CAST(ERROR_LINE() AS VARCHAR(10)) + CASE WHEN ERROR_PROCEDURE() IS NOT NULL THEN ' in ' + ERROR_PROCEDURE() ELSE '' END
	SET @Severity = ERROR_SEVERITY()
	set @ErrMsgBrief = left(@ErrMsg,100)

	exec msp_ProcessLog @PhaseError, @ErrMsgBrief, null, @Module, @Client
	exec msp_ProcessLog @PhaseEnd, @Process, null, @Module, @Client

	RAISERROR(@ErrMsg, @Severity , 1)

END CATCH

/****************************************************************************

			E N D															

****************************************************************************/


GO
/****** Object:  StoredProcedure [CustomerOutcomes].[pr_etl_DB_Transfer_PreAuthorisation]    Script Date: 7/3/2026 3:44:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/************************************************************************************************
  	 Program:  	pr_etl_DB_Transfer_PreAuthorisation
	  Author:	A Groves
Date created:	10/11/2016

		Type:	Customer Outcomes
		
 Description:   This proc populates table "CustomerOutcomes.owt_DB_Transfer_PreAuthorisation"
				from the staging table "CustomerOutcomes.sa_DB_Transfer_PreAuthorisation" that 
				was loaded by SSIS script "CustomerOutcomesDBToStaging32Bit.dtsx".

				It is called as follows:

				exec CustomerOutcomes.pr_etl_DB_Transfer_PreAuthorisation 'Openwork', 'CustomerOutcomes'
									
Amendment History								
-----------------								
											
Date		Who			Description				
----		---			-----------		
06/01/2017	A Groves	Re-written to MERGE the data rather than empty-and-load, in case the
						spreadsheet owner decides to empty out the old data, then the old data
						will not be lost in the table.	
************************************************************************************************/
CREATE PROCEDURE [CustomerOutcomes].[pr_etl_DB_Transfer_PreAuthorisation] 
	@Client		varchar(50),
	@Module		varchar(50)
as

set nocount on
set xact_abort on	-- Ensures all SQL statements are rolled back in the event of an error.

declare @PhaseStart					varchar(50),
		@PhaseEnd					varchar(50),
		@PhaseLog					varchar(50),
		@PhaseError					varchar(50),
		@Process					varchar(100),
		@ProcessMessage				varchar(100),
		@RowCount					int,
		@ErrMsg						varchar(400),
		@ErrMsgBrief				varchar(100), 
		@Severity 					int,
		@DateLastUpdated			datetime
		
/****************************************************************************

	Set initial parameters																
																		
****************************************************************************/

set @PhaseStart					= 'START'
set @PhaseEnd   				= 'END'
set @PhaseLog					= 'LOG'
set @PhaseError					= 'ERROR'
set @Process					= object_name(@@procid)
set @DateLastUpdated			= getdate()

/****************************************************************************

	Log start - we want this whether or not a rollback occurs
																		
****************************************************************************/

exec msp_ProcessLog @PhaseStart, @Process, null, @Module, @Client

/****************************************************************************

	Processing start - beyond this point everything should be capable of rollback
																		
****************************************************************************/

BEGIN TRY

	/****************************************************************************

		Start transaction
																			
	****************************************************************************/

	BEGIN TRANSACTION
	
	/****************************************************************************
	
		Insert rows into the destination table

	****************************************************************************/

	select top 0 * into #DB from CustomerOutcomes.owt_DB_Transfer_PreAuthorisation

	insert into #DB
	(
		DBSNumber,
		DateReceived,
		CaseStatus,
		DateCaseCompleted,
		DaysFromStartToFinish
	)
	select	DBSNumber,
			case isdate(DateReceived)
				when 1 then DateReceived
				else null
			end as DateReceived,
			CaseStatus,
			case isdate(DateCaseCompleted)
				when 1 then DateCaseCompleted
				else null
			end as DateCaseCompleted,
			case isnumeric(DaysFromStartToFinish)
				when 1 then convert(int,DaysFromStartToFinish)
				else null
			end as DaysFromStartToFinish
	from	CustomerOutcomes.sa_DB_Transfer_PreAuthorisation
	where	isnull(DBSNumber,'') <> ''
	
	/****************************************************************************
	
		Merge rows into the destination table

	****************************************************************************/

	merge	CustomerOutcomes.owt_DB_Transfer_PreAuthorisation as target
	using	#DB as source
	on		target.DBSNumber = source.DBSNumber 
	when	matched 
			and (isnull(target.DateReceived,'') <> isnull(source.DateReceived,'')
			or	 isnull(target.CaseStatus,'') <> isnull(source.CaseStatus,'')
			or	 isnull(target.DateCaseCompleted,'') <> isnull(source.DateCaseCompleted,'')
			or	 isnull(target.DaysFromStartToFinish,-1) <> isnull(source.DaysFromStartToFinish,-1))
	then	update 
				set target.DateReceived = source.DateReceived,
					target.CaseStatus = source.CaseStatus,
					target.DateCaseCompleted = source.DateCaseCompleted,
					target.DaysFromStartToFinish = source.DaysFromStartToFinish,
					target.DateLastUpdated = @DateLastUpdated
	when	not matched by target
	then	insert
			(
				DBSNumber,
				DateReceived,
				CaseStatus,
				DateCaseCompleted,
				DaysFromStartToFinish,
				DateInserted,
				DateLastUpdated
			)		
			values
			(
				source.DBSNumber,
				source.DateReceived,
				source.CaseStatus,
				source.DateCaseCompleted,
				source.DaysFromStartToFinish,
				@DateLastUpdated,
				@DateLastUpdated
			);

	/****************************************************************************

		Processing end
																		
	****************************************************************************/

	exec msp_ProcessLog @PhaseEnd, @Process, null, @Module, @Client

	/****************************************************************************

		End transaction
																			
	****************************************************************************/

	COMMIT TRANSACTION   

END TRY

BEGIN CATCH 

	IF @@TRANCOUNT <> 0
		ROLLBACK TRANSACTION
		
	SET @ErrMsg = @Process + ' failed.' + REPLACE(ERROR_MESSAGE(), '.', '') + ' (error no: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ') on line ' + CAST(ERROR_LINE() AS VARCHAR(10)) + CASE WHEN ERROR_PROCEDURE() IS NOT NULL THEN ' in ' + ERROR_PROCEDURE() ELSE '' END
	SET @Severity = ERROR_SEVERITY()
	set @ErrMsgBrief = left(@ErrMsg,100)

	exec msp_ProcessLog @PhaseError, @ErrMsgBrief, null, @Module, @Client
	exec msp_ProcessLog @PhaseEnd, @Process, null, @Module, @Client

	RAISERROR(@ErrMsg, @Severity , 1)

END CATCH

/****************************************************************************

			E N D															

****************************************************************************/


GO
/****** Object:  StoredProcedure [CustomerOutcomes].[pr_etl_Gov_CallOutcomeSummary]    Script Date: 7/3/2026 3:44:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/************************************************************************************************
  	 Program:  	pr_etl_Gov_CallOutcomeSummary
	  Author:	A Groves
Date created:	06/01/2017

		Type:	Customer Outcomes
		
 Description:   This proc populates table "CustomerOutcomes.owt_Gov_CallOutcomeSummary"
				from the staging table "CustomerOutcomes.sa_Gov_CallOutcomeSummary" that 
				was loaded by SSIS script "TandC Quality Calls Call Data.dtsx".

				It is called as follows:

				exec CustomerOutcomes.pr_etl_Gov_CallOutcomeSummary 'Openwork', 'CustomerOutcomes'
									
Amendment History								
-----------------								
											
Date		Who			Description				
----		---			-----------			
************************************************************************************************/
CREATE PROCEDURE [CustomerOutcomes].[pr_etl_Gov_CallOutcomeSummary] 
	@Client		varchar(50),
	@Module		varchar(50)
as

set nocount on
set xact_abort on	-- Ensures all SQL statements are rolled back in the event of an error.

declare @PhaseStart					varchar(50),
		@PhaseEnd					varchar(50),
		@PhaseLog					varchar(50),
		@PhaseError					varchar(50),
		@Process					varchar(100),
		@ProcessMessage				varchar(100),
		@RowCount					int,
		@ErrMsg						varchar(400),
		@ErrMsgBrief				varchar(100), 
		@Severity 					int,
		@DateLastUpdated			datetime
		
/****************************************************************************

	Set initial parameters																
																		
****************************************************************************/

set @PhaseStart					= 'START'
set @PhaseEnd   				= 'END'
set @PhaseLog					= 'LOG'
set @PhaseError					= 'ERROR'
set @Process					= object_name(@@procid)
set @DateLastUpdated			= getdate()

/****************************************************************************

	Log start - we want this whether or not a rollback occurs
																		
****************************************************************************/

exec msp_ProcessLog @PhaseStart, @Process, null, @Module, @Client

/****************************************************************************

	Processing start - beyond this point everything should be capable of rollback
																		
****************************************************************************/

BEGIN TRY

	/****************************************************************************

		Start transaction
																			
	****************************************************************************/

	BEGIN TRANSACTION
	
	/****************************************************************************
	
		Transform the data into a temporary table with the appropriate data types

	****************************************************************************/

	select top 0 * into #COS from CustomerOutcomes.owt_Gov_CallOutcomeSummary
	
	insert into #COS
	(
		CallMonth,
		ClientsContacted,
		TotalCallAttempts,
		TotalCompletedCalls,
		ConversionRateToClients,
		ConversionRateToCalls,
		BusinessArea
	)
	select	CallMonth,
			ClientsContacted,
			TotalCallAttempts,
			TotalCompletedCalls,
			ConversionRateToClients,
			ConversionRateToCalls,
			BusinessArea
	from	CustomerOutcomes.sa_Gov_CallOutcomeSummary
	where	isnull(ClientsContacted,'') <> ''
			
	/****************************************************************************
	
		Merge rows into the destination table

	****************************************************************************/

	merge	CustomerOutcomes.owt_Gov_CallOutcomeSummary as target
	using	#COS as source
	on		target.CallMonth = source.CallMonth 
	when	matched 
			and (isnull(target.ClientsContacted,-1) <> isnull(source.ClientsContacted,-1)
			or	 isnull(target.TotalCallAttempts,-1) <> isnull(source.TotalCallAttempts,-1)
			or	 isnull(target.TotalCompletedCalls,-1) <> isnull(source.TotalCompletedCalls,-1)
			or	 isnull(target.ConversionRateToClients,-1.0) <> isnull(source.ConversionRateToClients,-1.0)
			or	 isnull(target.ConversionRateToCalls,-1.0) <> isnull(source.ConversionRateToCalls,-1.0)
			or	 isnull(target.BusinessArea,'') <> isnull(source.BusinessArea,''))
	then	update 
				set	target.CallMonth = source.CallMonth,
					target.ClientsContacted = source.ClientsContacted,
					target.TotalCallAttempts = source.TotalCallAttempts,
					target.TotalCompletedCalls = source.TotalCompletedCalls,
					target.ConversionRateToClients = source.ConversionRateToClients,
					target.ConversionRateToCalls = source.ConversionRateToCalls,
					target.BusinessArea = source.BusinessArea,
					target.DateLastUpdated = @DateLastUpdated
	when	not matched by target
	then	insert
			(
				CallMonth,
				ClientsContacted,
				TotalCallAttempts,
				TotalCompletedCalls,
				ConversionRateToClients,
				ConversionRateToCalls,
				BusinessArea,
				DateInserted,
				DateLastUpdated
			)		
			values
			(
				source.CallMonth,
				source.ClientsContacted,
				source.TotalCallAttempts,
				source.TotalCompletedCalls,
				source.ConversionRateToClients,
				source.ConversionRateToCalls,
				source.BusinessArea,
				@DateLastUpdated,
				@DateLastUpdated
			);
			
	/****************************************************************************

		Processing end
																		
	****************************************************************************/

	exec msp_ProcessLog @PhaseEnd, @Process, null, @Module, @Client

	/****************************************************************************

		End transaction
																			
	****************************************************************************/

	COMMIT TRANSACTION   

END TRY

BEGIN CATCH 

	IF @@TRANCOUNT <> 0
		ROLLBACK TRANSACTION
		
	SET @ErrMsg = @Process + ' failed.' + REPLACE(ERROR_MESSAGE(), '.', '') + ' (error no: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ') on line ' + CAST(ERROR_LINE() AS VARCHAR(10)) + CASE WHEN ERROR_PROCEDURE() IS NOT NULL THEN ' in ' + ERROR_PROCEDURE() ELSE '' END
	SET @Severity = ERROR_SEVERITY()
	set @ErrMsgBrief = left(@ErrMsg,100)

	exec msp_ProcessLog @PhaseError, @ErrMsgBrief, null, @Module, @Client
	exec msp_ProcessLog @PhaseEnd, @Process, null, @Module, @Client

	RAISERROR(@ErrMsg, @Severity , 1)

END CATCH

/****************************************************************************

			E N D															

****************************************************************************/


GO
/****** Object:  StoredProcedure [CustomerOutcomes].[pr_etl_KPI_OGS_Summary]    Script Date: 7/3/2026 3:44:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/************************************************************************************************
  	 Program:  	pr_etl_KPI_OGS_Summary
	  Author:	A Groves
Date created:	29/11/2016

		Type:	Customer Outcomes
		
 Description:   This proc populates table "CustomerOutcomes.owt_KPI_OGS_Summary"
				from the OWS events table.
				
				The Customer Outcomes table and proc were introduced for the Customer
				Outcomes project (SR456151/CH15222). It is intended that this stored proc
				will be appended to the monthly KPI job as the last step. 

				It is called as follows:

				exec CustomerOutcomes.pr_etl_KPI_OGS_Summary 'Openwork', 'CustomerOutcomes'
									
Amendment History								
-----------------								
											
Date		Who			Description				
----		---			-----------			
************************************************************************************************/
CREATE PROCEDURE [CustomerOutcomes].[pr_etl_KPI_OGS_Summary] 
	@Client		varchar(50),
	@Module		varchar(50)
as

set nocount on
set xact_abort on	-- Ensures all SQL statements are rolled back in the event of an error.

declare @PhaseStart								varchar(50),
		@PhaseEnd								varchar(50),
		@PhaseLog								varchar(50),
		@PhaseError								varchar(50),
		@Process								varchar(100),
		@ProcessMessage							varchar(100),
		@RowCount								int,
		@ErrMsg									varchar(400),
		@ErrMsgBrief							varchar(100), 
		@Severity 								int,
		@DateLastUpdated						datetime,
		@AdvisersWithOverThresholdOGSClients	int,
		@AdvisersOfferingOGS					int,
		@ClientsReceivingOGSReviews				int,
		@ClientsReceivingOGSReports				int,
		@DueOrLateClientReviews					int,
		@DueOrLateClientReports					int	
			
/****************************************************************************

	Set initial parameters																
																		
****************************************************************************/

set @PhaseStart					= 'START'
set @PhaseEnd   				= 'END'
set @PhaseLog					= 'LOG'
set @PhaseError					= 'ERROR'
set @Process					= object_name(@@procid)
set @DateLastUpdated			= getdate()

/****************************************************************************

	Log start - we want this whether or not a rollback occurs
																		
****************************************************************************/

exec msp_ProcessLog @PhaseStart, @Process, null, @Module, @Client

/****************************************************************************

	Processing start - beyond this point everything should be capable of rollback
																		
****************************************************************************/

BEGIN TRY

	/****************************************************************************

		Start transaction
																			
	****************************************************************************/

	BEGIN TRANSACTION
	
	/****************************************************************************

		Report and Review Events
		========================
		Note that a client will always get a report (if signed up for OGS) but 
		may - or may not - have a review.
		
		The OWS tooltip describes the event statuses as follows:
		Scheduled - Any events due in the future and overdue by up to 30 days
		Due - Events overdue by between 31 and 60 days
		Late - Events overdue by more than 60 days

		NOTE:
		No date filter because we need to know the number of late reports back to
		the beginning of time.

	****************************************************************************/

	select	pop.UserID,
			evnt.PersonID,
			evnt.TypeID,												--1=Report event;2=Review event	
			max(erst.EventReminderStatusID) as EventReminderStatusID	--Prioritise scheduled before due before late
	into	#ClientEvents
	FROM	dbo.mi_insight_KPIPopulation pop 
			inner join dbo.sa_ows_Person pers on pers.AdviserUID = pop.UserUID
			inner join Events.sa_ows_Event evnt on evnt.PersonID = pers.PersonID 
			inner join StaticData.sa_ows_EventType evty on evty.EventTypeID = evnt.TypeID
			inner join StaticData.sa_ows_EventReminderStatus erst on erst.EventReminderStatusID = evnt.EventReminderStatusID
	where	pop.UserJobTitleCode in (4,42)			--4=Adviser;42=Schedule E Seller 
	and		pop.COBCompetencyCode in (2,3)			--2=Interim Competency;3=Fully Competent
	and		evnt.IsCancelled is null
	and		evnt.IsDeleted   is null
	and		erst.EventReminderStatusID in (1,2,3)	--1=Late;2=Due;3=Scheduled (i.e. active events)
	group	by pop.UserID, evnt.PersonID, evnt.TypeID
	
	/****************************************************************************
	
		Insert rows into the destination table

	****************************************************************************/

	select	@AdvisersWithOverThresholdOGSClients = count(*) 
	from
	(	select UserID, count(*) as ClientCount
		from
		(	select UserID, PersonID
			from #ClientEvents
			group by UserID, PersonID
		) RevAndRptCombined
		group by UserID
	) Advisers
	where	Advisers.ClientCount > 200

	select	@AdvisersOfferingOGS = count(distinct(UserID))
	from	#ClientEvents

	select	@ClientsReceivingOGSReviews = count(distinct(PersonID)) 
	from	#ClientEvents
	where	TypeID = 2	--2=Review

	select	@ClientsReceivingOGSReports = count(distinct(PersonID)) 
	from	#ClientEvents
	where	TypeID = 1	--1=Report
	and		PersonID not in (select PersonID from #ClientEvents where TypeID = 2)	--2=Review

	select	@DueOrLateClientReviews = count(distinct(PersonID)) 
	from	#ClientEvents
	where	TypeID = 2						--2=Review
	and		EventReminderStatusID in (1,2)	--1=Late;2=Due;3=Scheduled 

	select	@DueOrLateClientReports = count(distinct(PersonID))
	from	#ClientEvents
	where	TypeID = 1						--1=Report
	and		EventReminderStatusID in (1,2)	--1=Late;2=Due;3=Scheduled 
	and		PersonID not in (select	PersonID 
							 from	#ClientEvents 
							 where	TypeID = 2						--2=Review
							 and	EventReminderStatusID in (1,2))	--1=Late;2=Due;3=Scheduled 

	/****************************************************************************
	
		Insert rows into the destination table

	****************************************************************************/

	insert into CustomerOutcomes.owt_KPI_OGS_Summary
	(
		DateOfKPI,
		AdvisersWithOverThresholdOGSClients,
		AdvisersOfferingOGS,
		ClientsReceivingOGSReviews,
		ClientsReceivingOGSReports,
		DueOrLateClientReviews,
		DueOrLateClientReports,
		DateInserted,
		DateLastUpdated
	)
	select	dbo.owf_LastDayOfPrevMthDtTm(getdate()) as DateOfKPI,
			@AdvisersWithOverThresholdOGSClients as AdvisersWithOverThresholdOGSClients,
			@AdvisersOfferingOGS as AdvisersOfferingOGS,
			@ClientsReceivingOGSReviews as ClientsReceivingOGSReviews,
			@ClientsReceivingOGSReports as ClientsReceivingOGSReports,
			@DueOrLateClientReviews as DueOrLateClientReviews,
			@DueOrLateClientReports as DueOrLateClientReports,
			@DateLastUpdated as DateInserted,
			@DateLastUpdated as DateLastUpdated

	/****************************************************************************

		Processing end
																		
	****************************************************************************/

	exec msp_ProcessLog @PhaseEnd, @Process, null, @Module, @Client

	/****************************************************************************

		End transaction
																			
	****************************************************************************/

	COMMIT TRANSACTION   

END TRY

BEGIN CATCH 

	IF @@TRANCOUNT <> 0
		ROLLBACK TRANSACTION
		
	SET @ErrMsg = @Process + ' failed.' + REPLACE(ERROR_MESSAGE(), '.', '') + ' (error no: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ') on line ' + CAST(ERROR_LINE() AS VARCHAR(10)) + CASE WHEN ERROR_PROCEDURE() IS NOT NULL THEN ' in ' + ERROR_PROCEDURE() ELSE '' END
	SET @Severity = ERROR_SEVERITY()
	set @ErrMsgBrief = left(@ErrMsg,100)

	exec msp_ProcessLog @PhaseError, @ErrMsgBrief, null, @Module, @Client
	exec msp_ProcessLog @PhaseEnd, @Process, null, @Module, @Client

	RAISERROR(@ErrMsg, @Severity , 1)

END CATCH

/****************************************************************************

			E N D															

****************************************************************************/


GO
/****** Object:  StoredProcedure [CustomerOutcomes].[pr_etl_KPI_RiskRatingHistory]    Script Date: 7/3/2026 3:44:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/************************************************************************************************
  	 Program:  	pr_etl_KPI_RiskRatingHistory
	  Author:	A Groves
Date created:	24/11/2016

		Type:	Customer Outcomes
		
 Description:   This proc populates table "CustomerOutcomes.owt_KPIRiskRatingHistory"
				from table "dbo.mi_insight_RiskAssessment". 
				
				The Customer Outcomes table and proc were introduced for the Customer
				Outcomes project (SR456151/CH15222). It is intended that this stored proc
				will be appended to the monthly KPI job as the last step. 

				It is called as follows:

				exec CustomerOutcomes.pr_etl_KPI_RiskRatingHistory 'Openwork', 'CustomerOutcomes'
									
Amendment History								
-----------------								
											
Date		Who			Description				
----		---			-----------			
************************************************************************************************/
CREATE PROCEDURE [CustomerOutcomes].[pr_etl_KPI_RiskRatingHistory] 
	@Client		varchar(50),
	@Module		varchar(50)
as

set nocount on
set xact_abort on	-- Ensures all SQL statements are rolled back in the event of an error.

declare @PhaseStart					varchar(50),
		@PhaseEnd					varchar(50),
		@PhaseLog					varchar(50),
		@PhaseError					varchar(50),
		@Process					varchar(100),
		@ProcessMessage				varchar(100),
		@RowCount					int,
		@ErrMsg						varchar(400),
		@ErrMsgBrief				varchar(100), 
		@Severity 					int,
		@LargeNegativeNumber		decimal(16,2),
		@FinancialPeriodFromDate	date,
		@FinancialPeriodEndDate		date,
		@FinancialPeriodToDate		date,
		@DateLastUpdated			datetime
		
/****************************************************************************

	Set initial parameters																
																		
****************************************************************************/

set @PhaseStart					= 'START'
set @PhaseEnd   				= 'END'
set @PhaseLog					= 'LOG'
set @PhaseError					= 'ERROR'
set @Process					= object_name(@@procid)
set @DateLastUpdated			= getdate()

/****************************************************************************

	Log start - we want this whether or not a rollback occurs
																		
****************************************************************************/

exec msp_ProcessLog @PhaseStart, @Process, null, @Module, @Client

/****************************************************************************

	Processing start - beyond this point everything should be capable of rollback
																		
****************************************************************************/

BEGIN TRY

	/****************************************************************************

		Start transaction
																			
	****************************************************************************/

	BEGIN TRANSACTION
	
	/****************************************************************************
	
		Delete the row from the destination table (if it exists) prior to 
		the re-load.

	****************************************************************************/

	delete from CustomerOutcomes.owt_KPIRiskRatingHistory
	where DateOfRiskAssessment in (select max(RA_DATE) from dbo.mi_insight_RiskAssessment)
	
	set @RowCount = @@rowcount

	set @ProcessMessage = 'Deletion Completed. Number of rows = ' + convert(varchar(20),@RowCount)	
	exec msp_ProcessLog @PhaseLog, @ProcessMessage, null, @Module, @Client

	/****************************************************************************
	
		Insert rows into the destination table

	****************************************************************************/

	insert into CustomerOutcomes.owt_KPIRiskRatingHistory
	(
		DateOfRiskAssessment,
		GreenAdvisers,
		AmberAdvisers,
		RedAdvisers,
		RedFlagAdvisers,
		GreenFirms,
		AmberFirms,
		RedFirms,
		RedFlagFirms,
		DateInserted,
		DateLastUpdated
	)
	select	RA_Date as DateOfRiskAssessment,
			sum(case when RA_USR_Type = 1 and RA_Status = 1 then 1 else 0 end) as GreenAdvisers,
			sum(case when RA_USR_Type = 1 and RA_Status = 2 then 1 else 0 end) as AmberAdvisers,
			sum(case when RA_USR_Type = 1 and RA_Status = 3 then 1 else 0 end) as RedAdvisers,
			sum(case when RA_USR_Type = 1 and RA_Status = 4 then 1 else 0 end) as RedFlagAdvisers,
			sum(case when RA_USR_Type = 9 and RA_Status = 1 then 1 else 0 end) as GreenFirms,
			sum(case when RA_USR_Type = 9 and RA_Status = 2 then 1 else 0 end) as AmberFirms,
			sum(case when RA_USR_Type = 9 and RA_Status = 3 then 1 else 0 end) as RedFirms,
			sum(case when RA_USR_Type = 9 and RA_Status = 4 then 1 else 0 end) as RedFlagFirms,
			@DateLastUpdated as DateInserted,
			@DateLastUpdated as DateLastUpdated
	from dbo.mi_insight_RiskAssessment
	group by RA_Date

	set @RowCount = @@rowcount

	set @ProcessMessage = 'Insertion Completed. Number of rows = ' + convert(varchar(20),@RowCount)	
	exec msp_ProcessLog @PhaseLog, @ProcessMessage, null, @Module, @Client

	/****************************************************************************

		Processing end
																		
	****************************************************************************/

	exec msp_ProcessLog @PhaseEnd, @Process, null, @Module, @Client

	/****************************************************************************

		End transaction
																			
	****************************************************************************/

	COMMIT TRANSACTION   

END TRY

BEGIN CATCH 

	IF @@TRANCOUNT <> 0
		ROLLBACK TRANSACTION
		
	SET @ErrMsg = @Process + ' failed.' + REPLACE(ERROR_MESSAGE(), '.', '') + ' (error no: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ') on line ' + CAST(ERROR_LINE() AS VARCHAR(10)) + CASE WHEN ERROR_PROCEDURE() IS NOT NULL THEN ' in ' + ERROR_PROCEDURE() ELSE '' END
	SET @Severity = ERROR_SEVERITY()
	set @ErrMsgBrief = left(@ErrMsg,100)

	exec msp_ProcessLog @PhaseError, @ErrMsgBrief, null, @Module, @Client
	exec msp_ProcessLog @PhaseEnd, @Process, null, @Module, @Client

	RAISERROR(@ErrMsg, @Severity , 1)

END CATCH

/****************************************************************************

			E N D															

****************************************************************************/


GO
/****** Object:  StoredProcedure [CustomerOutcomes].[pr_etl_LAT_PreAuthorisation]    Script Date: 7/3/2026 3:44:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/************************************************************************************************
  	 Program:  	pr_etl_LAT_PreAuthorisation
	  Author:	A Groves
Date created:	11/11/2016

		Type:	Customer Outcomes
		
 Description:   This proc populates table "CustomerOutcomes.owt_LAT_PreAuthorisation"
				from the staging table "CustomerOutcomes.sa_LAT_PreAuthorisation" that 
				was loaded by SSIS script "CustomerOutcomesLATToStaging32Bit.dtsx".

				It is called as follows:

				exec CustomerOutcomes.pr_etl_LAT_PreAuthorisation 'Openwork', 'CustomerOutcomes'
									
Amendment History								
-----------------								
											
Date		Who			Description				
----		---			-----------			
************************************************************************************************/
CREATE PROCEDURE [CustomerOutcomes].[pr_etl_LAT_PreAuthorisation] 
	@Client		varchar(50),
	@Module		varchar(50)
as

set nocount on
set xact_abort on	-- Ensures all SQL statements are rolled back in the event of an error.

declare @PhaseStart					varchar(50),
		@PhaseEnd					varchar(50),
		@PhaseLog					varchar(50),
		@PhaseError					varchar(50),
		@Process					varchar(100),
		@ProcessMessage				varchar(100),
		@RowCount					int,
		@ErrMsg						varchar(400),
		@ErrMsgBrief				varchar(100), 
		@Severity 					int,
		@DateLastUpdated			datetime
		
/****************************************************************************

	Set initial parameters																
																		
****************************************************************************/

set @PhaseStart					= 'START'
set @PhaseEnd   				= 'END'
set @PhaseLog					= 'LOG'
set @PhaseError					= 'ERROR'
set @Process					= object_name(@@procid)
set @DateLastUpdated			= getdate()

/****************************************************************************

	Log start - we want this whether or not a rollback occurs
																		
****************************************************************************/

exec msp_ProcessLog @PhaseStart, @Process, null, @Module, @Client

/****************************************************************************

	Processing start - beyond this point everything should be capable of rollback
																		
****************************************************************************/

BEGIN TRY

	/****************************************************************************

		Start transaction
																			
	****************************************************************************/

	BEGIN TRANSACTION
	
	/****************************************************************************
	
		Transform the data into a temporary table with the appropriate data types

	****************************************************************************/

	select top 0 * into #LAT from CustomerOutcomes.owt_LAT_PreAuthorisation
	
	insert into #LAT
	(
		LATID,
		ReasonForPreAuthCode,
		MultiplePreAuthReasons,	
		DateReceived,
		DateOfCaseAllocation,
		DateOfFinalDecision,
		DaysFromAllocToFinalDecision,
		MonthClosed,
		FinalResult
	)
	select	LATID,
			case 
				when ReasonForPreAuth = 'More than one reason' then 12
				when PATINDEX('%,%',ReasonForPreAuth) > 0 and isnull(MultiplePreAuthReasons,'') = '' then 12
				when isnumeric(ReasonForPreAuth) = 1 then convert(int,ReasonForPreAuth)
				else null
			end as ReasonForPreAuthCode,
			case
				when PATINDEX('%,%',ReasonForPreAuth) > 0 and isnull(MultiplePreAuthReasons,'') = '' then ReasonForPreAuth
				else MultiplePreAuthReasons		
			end as MultiplePreAuthReasons,
			case isdate(DateReceived)
				when 1 then DateReceived
				else null
			end as DateReceived,
			case isdate(DateOfCaseAllocation)
				when 1 then DateOfCaseAllocation
				else null
			end as DateOfCaseAllocation,
			case isdate(DateOfFinalDecision)
				when 1 then DateOfFinalDecision
				else null
			end as DateOfFinalDecision,
			case 
				when isdate(DateOfCaseAllocation) = 1 and isdate(DateOfFinalDecision) = 1
						then datediff(dd,DateOfCaseAllocation,DateOfFinalDecision) + 1 
				else null
			end as DaysFromAllocToFinalDecision,
			MonthClosed,
			FinalResult
	from	CustomerOutcomes.sa_LAT_PreAuthorisation
	where	isnull(LATID,'') <> ''

	/****************************************************************************
	
		Merge rows into the destination table

	****************************************************************************/

	merge	CustomerOutcomes.owt_LAT_PreAuthorisation as target
	using	#LAT as source
	on		target.LATID = source.LATID 
	when	matched 
			and (isnull(target.ReasonForPreAuthCode,-1) <> isnull(source.ReasonForPreAuthCode,-1)
			or	 isnull(target.MultiplePreAuthReasons,'') <> isnull(source.MultiplePreAuthReasons,'')
			or	 isnull(target.DateReceived,'') <> isnull(source.DateReceived,'')
			or	 isnull(target.DateOfCaseAllocation,'') <> isnull(source.DateOfCaseAllocation,'')
			or	 isnull(target.DateOfFinalDecision,'') <> isnull(source.DateOfFinalDecision,'')
			or	 isnull(target.DaysFromAllocToFinalDecision,-1) <> isnull(source.DaysFromAllocToFinalDecision,-1)
			or	 isnull(target.MonthClosed,'') <> isnull(source.MonthClosed,'')
			or	 isnull(target.FinalResult,'') <> isnull(source.FinalResult,''))
	then	update 
				set target.ReasonForPreAuthCode = source.ReasonForPreAuthCode,
					target.MultiplePreAuthReasons = source.MultiplePreAuthReasons,
					target.DateReceived = source.DateReceived,
					target.DateOfCaseAllocation = source.DateOfCaseAllocation,
					target.DateOfFinalDecision = source.DateOfFinalDecision,
					target.DaysFromAllocToFinalDecision = source.DaysFromAllocToFinalDecision,
					target.MonthClosed = source.MonthClosed,
					target.FinalResult = source.FinalResult,
					target.DateLastUpdated = @DateLastUpdated
	when	not matched by target
	then	insert
			(
				LATID,
				ReasonForPreAuthCode,
				MultiplePreAuthReasons,	
				DateReceived,
				DateOfCaseAllocation,
				DateOfFinalDecision,
				DaysFromAllocToFinalDecision,
				MonthClosed,
				FinalResult,
				DateInserted,
				DateLastUpdated
			)		
			values
			(
				source.LATID,
				source.ReasonForPreAuthCode,
				source.MultiplePreAuthReasons,	
				source.DateReceived,
				source.DateOfCaseAllocation,
				source.DateOfFinalDecision,
				source.DaysFromAllocToFinalDecision,
				source.MonthClosed,
				source.FinalResult,
				@DateLastUpdated,
				@DateLastUpdated
			);

	/****************************************************************************

		Processing end
																		
	****************************************************************************/

	exec msp_ProcessLog @PhaseEnd, @Process, null, @Module, @Client

	/****************************************************************************

		End transaction
																			
	****************************************************************************/

	COMMIT TRANSACTION   

END TRY

BEGIN CATCH 

	IF @@TRANCOUNT <> 0
		ROLLBACK TRANSACTION
		
	SET @ErrMsg = @Process + ' failed.' + REPLACE(ERROR_MESSAGE(), '.', '') + ' (error no: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ') on line ' + CAST(ERROR_LINE() AS VARCHAR(10)) + CASE WHEN ERROR_PROCEDURE() IS NOT NULL THEN ' in ' + ERROR_PROCEDURE() ELSE '' END
	SET @Severity = ERROR_SEVERITY()
	set @ErrMsgBrief = left(@ErrMsg,100)

	exec msp_ProcessLog @PhaseError, @ErrMsgBrief, null, @Module, @Client
	exec msp_ProcessLog @PhaseEnd, @Process, null, @Module, @Client

	RAISERROR(@ErrMsg, @Severity , 1)

END CATCH

/****************************************************************************

			E N D															

****************************************************************************/


GO
/****** Object:  StoredProcedure [CustomerOutcomes].[pr_etl_PPS_PreAuthorisation]    Script Date: 7/3/2026 3:44:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/************************************************************************************************
  	 Program:  	pr_etl_PPS_PreAuthorisation
	  Author:	A Groves
Date created:	09/11/2016

		Type:	Customer Outcomes
		
 Description:   This proc populates table "CustomerOutcomes.owt_PPS_PreAuthorisation"
				from the staging table "CustomerOutcomes.sa_PPS_PreAuthorisation" that 
				was loaded by SSIS script "CustomerOutcomesPPSToStaging32Bit.dtsx".

				It is called as follows:

				exec CustomerOutcomes.pr_etl_PPS_PreAuthorisation 'Openwork', 'CustomerOutcomes'
									
Amendment History								
-----------------								
											
Date		Who			Description				
----		---			-----------			
************************************************************************************************/
CREATE PROCEDURE [CustomerOutcomes].[pr_etl_PPS_PreAuthorisation] 
	@Client		varchar(50),
	@Module		varchar(50)
as

set nocount on
set xact_abort on	-- Ensures all SQL statements are rolled back in the event of an error.

declare @PhaseStart					varchar(50),
		@PhaseEnd					varchar(50),
		@PhaseLog					varchar(50),
		@PhaseError					varchar(50),
		@Process					varchar(100),
		@ProcessMessage				varchar(100),
		@RowCount					int,
		@ErrMsg						varchar(400),
		@ErrMsgBrief				varchar(100), 
		@Severity 					int,
		@LargeNegativeNumber		decimal(16,2),
		@FinancialPeriodFromDate	date,
		@FinancialPeriodEndDate		date,
		@FinancialPeriodToDate		date,
		@DateLastUpdated			datetime
		
/****************************************************************************

	Set initial parameters																
																		
****************************************************************************/

set @PhaseStart					= 'START'
set @PhaseEnd   				= 'END'
set @PhaseLog					= 'LOG'
set @PhaseError					= 'ERROR'
set @Process					= object_name(@@procid)
set @DateLastUpdated			= getdate()

/****************************************************************************

	Log start - we want this whether or not a rollback occurs
																		
****************************************************************************/

exec msp_ProcessLog @PhaseStart, @Process, null, @Module, @Client

/****************************************************************************

	Processing start - beyond this point everything should be capable of rollback
																		
****************************************************************************/

BEGIN TRY

	/****************************************************************************

		Start transaction
																			
	****************************************************************************/

	BEGIN TRANSACTION
	
	/****************************************************************************
	
		Transform the data into a temporary table with the appropriate data types

	****************************************************************************/

	select top 0 * into #PPS from CustomerOutcomes.owt_PPS_PreAuthorisation
	
	insert into #PPS
	(
		PPSNumber,
		DateReceived,
		DateOfPPSDecision,
		DaysToDecision,
		Outcome
	)
	select	PPSNumber,
			case isdate(DateReceived)
				when 1 then DateReceived
				else null
			end as DateReceived,
			case isdate(DateOfPPSDecision)
				when 1 then DateOfPPSDecision
				else null
			end as DateOfPPSDecision,
			datediff(dd, DateReceived, DateOfPPSDecision)+1 as DaysToDecision,
			Outcome
	from	CustomerOutcomes.sa_PPS_PreAuthorisation
	where	isnull(PPSNumber,'') <> ''
			
	/****************************************************************************
	
		Merge rows into the destination table

	****************************************************************************/

	merge	CustomerOutcomes.owt_PPS_PreAuthorisation as target
	using	#PPS as source
	on		target.PPSNumber = source.PPSNumber 
	when	matched 
			and (isnull(target.DateReceived,'') <> isnull(source.DateReceived,'')
			or	 isnull(target.DateOfPPSDecision,'') <> isnull(source.DateOfPPSDecision,'')
			or	 isnull(target.DaysToDecision,-1) <> isnull(source.DaysToDecision,-1)
			or	 isnull(target.Outcome,'') <> isnull(source.Outcome,''))
	then	update 
				set target.DateReceived = source.DateReceived,
					target.DateOfPPSDecision = source.DateOfPPSDecision,
					target.DaysToDecision = source.DaysToDecision,
					target.Outcome = source.Outcome,
					target.DateLastUpdated = @DateLastUpdated
	when	not matched by target
	then	insert
			(
				PPSNumber,
				DateReceived,
				DateOfPPSDecision,
				DaysToDecision,
				Outcome,
				DateInserted,
				DateLastUpdated
			)		
			values
			(
				source.PPSNumber,
				source.DateReceived,
				source.DateOfPPSDecision,
				source.DaysToDecision,
				source.Outcome,
				@DateLastUpdated,
				@DateLastUpdated
			);
			
	/****************************************************************************

		Processing end
																		
	****************************************************************************/

	exec msp_ProcessLog @PhaseEnd, @Process, null, @Module, @Client

	/****************************************************************************

		End transaction
																			
	****************************************************************************/

	COMMIT TRANSACTION   

END TRY

BEGIN CATCH 

	IF @@TRANCOUNT <> 0
		ROLLBACK TRANSACTION
		
	SET @ErrMsg = @Process + ' failed.' + REPLACE(ERROR_MESSAGE(), '.', '') + ' (error no: ' + CAST(ERROR_NUMBER() AS VARCHAR(10)) + ') on line ' + CAST(ERROR_LINE() AS VARCHAR(10)) + CASE WHEN ERROR_PROCEDURE() IS NOT NULL THEN ' in ' + ERROR_PROCEDURE() ELSE '' END
	SET @Severity = ERROR_SEVERITY()
	set @ErrMsgBrief = left(@ErrMsg,100)

	exec msp_ProcessLog @PhaseError, @ErrMsgBrief, null, @Module, @Client
	exec msp_ProcessLog @PhaseEnd, @Process, null, @Module, @Client

	RAISERROR(@ErrMsg, @Severity , 1)

END CATCH

/****************************************************************************

			E N D															

****************************************************************************/


GO
/****** Object:  StoredProcedure [dbo].[appman_test1]    Script Date: 7/3/2026 3:44:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO

/*********************************************************************************************************

Program:		[OPENWORK\reedp].[appman_service5]O365OnChargingMerge				
Author:			Richard Abbott
Date created:	28/05/2020
											
Description:
===========

This proc is used for importing the Microsoft O365 data into the OpenAccess [OPENWORK\reedp].[appman_service5] table.

This process uses a MERGE statement. However, there is no DELETE component in case the staging table
breaks and we end up with an empty staging table. In this scenario we wouldn't want this process to
remove all the payments from the OpenAccess download table.

NOTE: Exclude any rows where the Enterprise UID is null as these are inaccessible in OpenAccess.

This proc is called as follows:
	
	exec [dbo].[[OPENWORK\reedp].[appman_service5]O365OnChargingMerge] 'Openwork', 'Services'

AMENDMENT HISTORY				
=================								

Date		Author		Description
----		------		-----------

*************************************************************************************************************/

CREATE PROCEDURE [dbo].[appman_test1]
	@Client		varchar(50),
	@Module		Varchar(50)

AS

set nocount on

declare		@PhaseStart				varchar(50),
			@PhaseEnd				varchar(50),
			@PhaseError				varchar(50),
			@PhaseLog				varchar(50),
			@ProcName				varchar(100),
			@ProcessMessage			varchar(100),
			@RowCount				int,
			@OALRowCount			int,
			@ErrMsg					nvarchar(4000),
			@ErrMsgBrief			nvarchar(100),
			@ErrNum					int,
			@ErrSev					int,
			@ErrLine				int,
			@ErrState				int,
			@DateLastUpdated		datetime,
			@NullDate				datetime
			
/****************************************************************************

	Set initial parameters																
																		
****************************************************************************/

set @ProcName			= object_name(@@procid)
set @PhaseStart			= 'START'
set @PhaseEnd			= 'END'
set @PhaseError			= 'ERROR'
set @PhaseLog			= 'LOG'
set @ErrNum				= 0	
set @DateLastUpdated	= getdate()
set @NullDate			= '1900-01-01'

-- We want this logging irrespective of whether or not there is a rollback
exec msp_ProcessLog @PhaseStart, @ProcName, null, @Module, @Client

/****************************************************************************

	Populate the table																
																		
****************************************************************************/

SET XACT_ABORT ON	-- Needed if XACT_STATE() function is used.

BEGIN TRY

	/****************************************************************************

		Merge the tables
																		
	****************************************************************************/

	BEGIN TRANSACTION
	
	declare @SummaryOfChanges table (Change varchar(20))
	;with CTE_appman_charge5
	as
	(
		select	top 100 percent
				ocs.EnterpriseUID,
				ent.Descn as EnterpriseName,
				ocs.AdviserUID,
				adv.Descn as AdviserName,
				ocs.O365LicenseID as 'SourceReference',
				ocs.TransactionDate as TransactionDateTime,
				ocs.Firstname as ClientFirstname,
				ocs.Surname as ClientLastname,
				'O365 License Charge' as Service1,
				--ocs.PreviousPostcode as Service2,
				--case when ocs.ServiceErrorFlag is not null then 'Yes' else '' end as ServiceErrorFlag,
				ocs.FeeType,
				ocs.NetAmount,
				ocs.VATAmount,
				ocs.GrossAmount,
				ocs.Month,
				ocs.Source,
				ocs.SourceType,
				ocs.ID as SourceID,
				ocs.StandingOrderCode,
				ocs.StandingOrderDescription,
				isnull(s.PaymentCollected,0) as PaymentCollected,
				s.PaymentCollectedDate,
				s.StandingOrderID,
				ocs.DateInserted,
				ocs.DateLastUpdated
		from	[OPENWORK\reedp].[appman_charge5] ocs
				left join mstt_Agents adv on adv.Code = ocs.AdviserUID
				left join mstt_Agents ent on ent.Code = ocs.EnterpriseUID
				left join [OPENWORK\reedp].[appman_service5] s on s.SourceID = ocs.ID and s.Source = 'Microsoft' and s.SourceType = 'Office365'
		where	ocs.EnterpriseUID is not null	--Should have been trapped - but belt and braces
		and		ocs.Valid = 1					--Only valid transactions to go through to OpenAccess
		
		order	by ocs.O365LicenseID
	)
	merge	[OPENWORK\reedp].[appman_service5] as trg
	using	CTE_appman_charge5 as src
	on		trg.SourceReference = src.SourceReference
	when	matched 
	and		(isnull(trg.EnterpriseName,'') <> isnull(src.EnterpriseName,'')
	or		isnull(trg.AdviserName,'') <> isnull(src.AdviserName,''))
		then	update 
				set trg.EnterpriseName				= src.EnterpriseName,
					trg.AdviserName					= src.AdviserName,
					trg.DateLastUpdated				= @DateLastUpdated
	when	not matched by target 
	then	insert
			(
				EnterpriseUID,
				EnterpriseName,
				AdviserUID,
				AdviserName,
				SourceReference,
				TransactionDateTime,
				ClientFirstname,
				ClientLastname,
				Service1,
				--Service2,
				--ServiceErrorFlag,
				FeeType,
				NetAmount,
				VATAmount,
				GrossAmount,
				Month,
				Source,
				SourceType,
				SourceID,
				StandingOrderCode,
				StandingOrderDescription,
				PaymentCollected,
				PaymentCollectedDate,
				StandingOrderID,
				DateInserted,
				DateLastUpdated
			)
			values
			(
				src.EnterpriseUID,
				src.EnterpriseName,
				src.AdviserUID,
				src.AdviserName,
				src.SourceReference,
				src.TransactionDateTime,
				src.ClientFirstname,
				src.ClientLastname,
				src.Service1,
				-- src.Service2,
				-- src.ServiceErrorFlag,
				src.FeeType,
				src.NetAmount,
				src.VATAmount,
				src.GrossAmount,
				src.Month,
				src.Source,
				src.SourceType,
				src.SourceID,
				src.StandingOrderCode,
				src.StandingOrderDescription,
				src.PaymentCollected,
				src.PaymentCollectedDate,
				src.StandingOrderID,
				@DateLastUpdated,
				@DateLastUpdated
			)				
	output $action into @SummaryOfChanges;		--Merge statements must have a ;
						
	COMMIT TRANSACTION      
	
	select	@RowCount = COUNT(*)
	from	@SummaryOfChanges
	where	Change = 'INSERT'

	set @ProcessMessage = '[OPENWORK\reedp].[appman_service5] (insert) = ' + convert(nvarchar(10), @RowCount)
	--exec msp_ProcessLog @PhaseLog, @ProcessMessage, null, @Module, @Client

	select	@RowCount = COUNT(*)
	from	@SummaryOfChanges
	where	Change = 'UPDATE'

	set @ProcessMessage = '[OPENWORK\reedp].[appman_service5] (update) = ' + convert(nvarchar(10), @RowCount)
	--exec msp_ProcessLog @PhaseLog, @ProcessMessage, null, @Module, @Client

	/****************************************************************************

		T H E   E N D
																		
	****************************************************************************/
	
	--exec msp_ProcessLog @PhaseEnd, @ProcName, null, @Module, @Client

END TRY

BEGIN CATCH 

	select @ErrNum = ERROR_NUMBER(), @ErrMsg = ERROR_MESSAGE(), @ErrSev = ERROR_SEVERITY(), @ErrLine = ERROR_LINE(), @ErrState = XACT_STATE()
	set @ErrMsg = REPLACE(@ErrMsg, '.', '') + ' (error no: ' + CAST(@ErrNum AS VARCHAR(10)) + ') on line ' + CAST(@ErrLine AS VARCHAR(10))
	
	-- Test XACT_STATE for 0, 1, or -1.
    -- If 1, the transaction is committable.
    -- If -1, the transaction is uncommittable and should be rolled back.
    -- If 0, there is no transaction and a commit or rollback operation would generate an error.

	if @ErrState = -1			-- Transaction is uncommitable
		rollback transaction

	if @ErrState = 1			
		commit transaction

	-- Error message line 1
	set @ErrMsgBrief = left(@ErrMsg,100)
--	exec msp_ProcessLog @PhaseError, @ErrMsgBrief, null, @Module, @Client
	
	-- Error message line 2 - if any text exists
	set @ErrMsgBrief = substring(@ErrMsg,101,100)
	if len(@ErrMsgBrief) > 0
	--	exec msp_ProcessLog @PhaseError, @ErrMsgBrief, null, @Module, @Client

	--exec msp_ProcessLog @PhaseEnd, @ProcName, null, @Module, @Client

	RAISERROR(@ErrMsg, @ErrSev , 1)

END CATCH

/****************************************************************************

			E N D															

****************************************************************************/

return @ErrNum
GO
/****** Object:  StoredProcedure [dbo].[appman_updnullsellername]    Script Date: 7/3/2026 3:44:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE PROCEDURE [dbo].[appman_updnullsellername]
@sourceid int,
@policy nvarchar(100),
@sellercode  nvarchar(100),
@sellername nvarchar(100),
@sellerforename nvarchar(100),
@sellersurname  nvarchar(100),
@runlive int   -- 0 is run the select only and 1 is to run select and the update

AS

declare @rowcount int



SELECT 'Record to update', *
  FROM [prod_zurich_openwork_datawarehouse].[dbo].[msit_OpenworkAdviserListing] --where --Policy='P11408-449/001'
  where SellerName is null and sourceid=@sourceid and policy=@policy order by startdate

if @runlive=1
BEGIN

	update  [prod_zurich_openwork_datawarehouse].[dbo].[msit_OpenworkAdviserListing]
	set SellerCode=@sellercode,SellerName=@sellername,SellerForename=@sellerforename ,SellerSurname=@sellersurname where 
	sellername is null and sourceid=@sourceid and policy=@policy;
	set @RowCount = @@rowcount

	if @rowcount>0
	begin
		select 'UPDATED - Proof here: ', * FROM [prod_zurich_openwork_datawarehouse].[dbo].[msit_OpenworkAdviserListing] --where --Policy='P11408-449/001'
		where sourceid=@sourceid and policy=@policy 
	end

END


select 'NOT UPDATED AS RUNLIVE PARAMETER SET TO 0' WHERE @runlive=0



if @Rowcount > 0 and @runlive=1
BEGIN

select 'Updated successfully '+cast(@rowcount as nvarchar)+' rows'

END;





GO
/****** Object:  StoredProcedure [dbo].[box_siml_view]    Script Date: 7/3/2026 3:44:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO















CREATE               PROCEDURE [dbo].[box_siml_view]
AS


truncate table Box_SIMLV


declare policy_cursor cursor
for
 select distinct 
    [Policy_Number]

from head_office_systems.dbo.Box_SIML
 for read only

declare
  @polnum                 varchar(20)

open policy_cursor
fetch policy_cursor
into
  @polnum



while (@@fetch_status = 0)
   begin



insert into Box_SIMLV(ID, PolicyID, TransactionNumber, TransType, CommissionTypeDesc, ProductProviderCode,Amount,TermYears, TermMonths, TransactionDate, AdminMethod, SubsequentPurchase, CodeCommissionShapeID, ProposalDate, 
                      Frequency, CommRenewalFrequency, FIRSTNAMES, NAME, BIRTHDATE, POSTCODE, ProductCode, CONT_NUM, 
                      PolicyRef, WrittenTranID, CommissionFlex, CommBasedOnPercent, CommExpectedUplift) 
SELECT  pt.ID, pt.PolicyID, pt.TransactionNumber, pt.TransType, pt.CommissionTypeDesc, pt.ProductProviderCode, pt.Amount, 
                      pt.TermYears, pt.TermMonths, pt.TransactionDate, pt.AdminMethod, pt.SubsequentPurchase, pt.CodeCommissionShapeID, pt.ProposalDate, 
                      pt.Frequency, pt.frequencydescription, c.FIRSTNAMES, c.NAME, c.BIRTHDATE, c.POSTCODE, pol.ProductCode, pol.CONT_NUM, 
                      pol.PolicyRef, pt.writtentranid,pt.CommTrialBalanceGiveUpPercent, pt.CommBasedOnPercent, pt.CommExpectedUplift
FROM         dbo.mstt_PolicyTransactions pt LEFT OUTER JOIN
                      dbo.msit_S_POLMAI pol ON pt.PolicyID = pol.POL_NUM LEFT OUTER JOIN
                      dbo.mstt_Clients c ON pol.CLIENT_NUM = c.CLIENT_NUM
WHERE     (pt.ProductProviderCode LIKE 'SIML')AND (pt.TransType IN (1, 17, 23, 39)) and (pt.transtypedesc <>'proposal'or(pt.transtypedesc like 'proposal' and pt.id <> '' and pt.issuedtranid is null)or  pt.writtentranid <> pt.id) 
    and pol.cont_num = @polnum


ORDER BY pt.PolicyID, pt.TransactionNumber


fetch policy_cursor
into
  @polnum

end


close policy_cursor
deallocate policy_cursor




GO
/****** Object:  StoredProcedure [dbo].[box_sterling_view]    Script Date: 7/3/2026 3:44:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO












CREATE            PROCEDURE [dbo].[box_sterling_view]
AS


truncate table Box_SterlingV

declare policy_cursor cursor
for
 select distinct 
    [Policy_Number]

from head_office_systems.dbo.Box_Sterling
 for read only

declare
  @polnum                 varchar(20)

open policy_cursor
fetch policy_cursor
into
  @polnum



while (@@fetch_status = 0)
   begin



insert into Box_SterlingV(ID, PolicyID, TransactionNumber, TransType, CommissionTypeDesc, ProductProviderCode,Amount,TermYears, TermMonths, TransactionDate, AdminMethod, SubsequentPurchase, CodeCommissionShapeID, ProposalDate, 
                      Frequency, CommRenewalFrequency, FIRSTNAMES, NAME, BIRTHDATE, POSTCODE, ProductCode, CONT_NUM, 
                      PolicyRef, WrittenTranID, CommissionFlex) 
SELECT  pt.ID, pt.PolicyID, pt.TransactionNumber, pt.TransType, pt.CommissionTypeDesc, pt.ProductProviderCode, pt.Amount, 
                      pt.TermYears, pt.TermMonths, pt.TransactionDate, pt.AdminMethod, pt.SubsequentPurchase, pt.CodeCommissionShapeID, pt.ProposalDate, 
                      pt.Frequency, pt.frequencydescription, c.FIRSTNAMES, c.NAME, c.BIRTHDATE, c.POSTCODE, pol.ProductCode, pol.CONT_NUM, 
                      pol.PolicyRef, pt.writtentranid,pt.CommTrialBalanceGiveUpPercent
FROM         dbo.mstt_PolicyTransactions pt LEFT OUTER JOIN
                      dbo.msit_S_POLMAI pol ON pt.PolicyID = pol.POL_NUM LEFT OUTER JOIN
                      dbo.mstt_Clients c ON pol.CLIENT_NUM = c.CLIENT_NUM
WHERE     (pt.ProductProviderCode LIKE 'Sterling')AND (pt.TransType IN (1, 17, 23, 39)) and (pt.transtypedesc <>'proposal'or(pt.transtypedesc like 'proposal' and pt.id <> '' and pt.issuedtranid is null)or  pt.writtentranid <> pt.id) 
    and pol.cont_num = @polnum 

ORDER BY pt.PolicyID, pt.TransactionNumber

fetch policy_cursor
into
  @polnum

end


close policy_cursor
deallocate policy_cursor




GO
/****** Object:  StoredProcedure [dbo].[box_summer_export_tala]    Script Date: 7/3/2026 3:44:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO























Create              PROCEDURE [dbo].[box_summer_export_tala]
AS
-- =============================================
-- Author:    <Author,,Name>
-- Create date: <Create Date,,>
-- Description: <Description,,>
-- =============================================
--Zurich EN temp file for transaction comparison
 






 create table #tempB
    (
    Gross_Premium varchar(10)
    ,Term varchar(10)
    ,Slice_Start_Date varchar(50)
    ,RPA_Indicator varchar(50)
                ,Slice_ID int
                ,Status varchar(10)
    )

--Swift Zurich temp file for transaction comparison
create table #tempSw
    (
    Gross_Premium varchar(10)
    ,Term varchar(10)
    ,Slice_Start_Date varchar(50)
    ,RPA_Indicator varchar(50)
                ,TransactionNumber int
                ,TransType varchar(20)
                ,paymenttype varchar(50)
    )



    --EN transaction processing working variables associated with #TempB table
     declare 
                   @gross varchar(10),
       @trm varchar(10),
       @slicedate varchar(50),
       @RPAInd varchar (10),
                   @MinB int,
                   @Status varchar(10)
                  
                 --Swift transaction processing working variables associated with #TempSw table
     declare 
                   @Amount varchar(10),
       @trms varchar(10),
       @TransactionDate varchar(50),
       @SubsequentPurchase varchar (10),
                   @MinS int,
                   @TransactionNo varchar(20),
                   @TransType varchar(50),
       @TransType2 varchar(50)

    --counter variable for #tempB records count
      declare @count int
      declare @counter2 int
                  declare @beforeDate varchar(50)
      declare @paymenttype varchar(50)
                  set @beforeDate ='20060131'



    --General variables
      declare @color varchar(20)
                  declare @Rating_Indicator2 varchar(20)
                  declare @Numsign varchar(20)


create table #tempCommon
(
Company_Code varchar(50)
,Policy_Number varchar(50)
,CaseID varchar(50)
,Product_Code varchar(50)
,Payment_Type varchar(50)
,Swift_Payment_Type varchar(50)
,SliceID int
,Swift_Transaction_No varchar(50)
,Status varchar(50)
,Status_Detail varchar(100)
,Swift_Transaction_Type varchar(50)
,Gross_Premium varchar(50)
,Swift_Premium varchar(100)
,Term varchar (50)
,Swift_Term varchar(50)
,SumAssured varchar(50)
,DGT_Indicator varchar(50)
,Old_Plan_Number varchar(50)
,Rating_Indicator varchar(50)
,Commission_Rate varchar(50)
,AgentCode varchar(50)
,IssueDate varchar(50)
,SliceStartDate varchar(50)
,SliceReasonCode varchar(50)
,increaseTypeFlag varchar(50)
,CommissionShapeType varchar(50)
,Frequency varchar(50)
,CommissionShapeTrail varchar(50)
,CommissionFlexibility varchar(50)
,CommissionRate varchar(50)
,ExecutionOnlyInd varchar(50)
,EventDesc varchar(100)
,SliceEndDate varchar(50)
,SliceStatus varchar(50)
,OwnerType varchar(50)
,ClientForename varchar(100)
,ClientSurname varchar(100)
,ClientSex varchar(50)
,ClientDOB varchar(50)
,Address1 varchar(100)
,Address2 varchar(100)
,Address3 varchar(100)
,Address4 varchar(100)
,Address5 varchar(100)
,PostCode varchar(50)
,Change varchar(50)

)

declare policy_cursor cursor
for
 select 
    [Policy_Number],
    [Client_Forename],
    [Client_Surname],
    [Client_DOB],
    [Postcode],
    [Company_Code],
    [Slice_Number],
    [Slice_Start_Date],
    [Slice_End_Date],
    [Gross_Premium],
    [Slice_Term],
    [Sum_Assured],
    [Policy_Status],
    [Slice_Type],
    [Agent_Code],
    [Event_Desc],
    [Slice_Status],
    [Owner_Type],
    [Client_Sex],
    [Address1],
    [Address2],
    [Address3]
from head_office_systems.dbo.Box_Tala order by Policy_Number, Slice_Number
 for read only

declare
  @polnum                 varchar(20),
  @CaseID                 varchar(10),
  @Client_Forename        varchar(50),
  @Client_Surname         varchar(50),
  @Client_DOB             varchar(20),
  @Postcode               varchar(20),
  @Company_Code           varchar(50),
  @ProductCode            varchar(50),
  @Slice_id               varchar(10),
  @Slice_Start_Date       varchar(50),
  @Slice_Status           varchar(20),
----
  @Status1  varchar(50),
  @Sum_Assured  varchar(50),
  @RPA_Indicator  varchar(50),
  @Old_Plan_Number  varchar(50),
  @Rating_Indicator varchar(50),
  @Commission_Rate  varchar(50),
  @Agent_Code varchar(50),
  @Client_Sex varchar(50),  
  @Address  varchar(500),
  @Issue_Date varchar(50),
  @SliceReasonCode  varchar(50),
  @Term varchar(50),
  @Gross_Premium  varchar(50),
  @Initial_Commission varchar(50),
  @Swift_Premium  varchar(50),
  @Swift_Term   varchar(50),
  @increaseTypeFlag varchar(50),
  @frequency varchar(50),
  @Status2  varchar(50)


--Tala variables

declare
  @Slice_End_Date         varchar(20),
  @Policy_Status          varchar(10),
  @Slice_Type             varchar(50),
  @Event_Desc             varchar(50),
  @Owner_Type             varchar(20),
--  @Client_Sex             varchar(20),
  @Address1               varchar(200),
  @Address2               varchar(200),
  @Address3               varchar(200)
  
   

  


open policy_cursor
fetch policy_cursor
into
  @polnum, 
  @Client_Forename,
  @Client_Surname,
  @Client_DOB,
  @Postcode,
  @Company_Code, 
  @Slice_id,
  @Slice_Start_Date,
  @Slice_End_Date,
  @Gross_Premium,
  @term,
  @Sum_Assured,
  @Policy_Status,
  @Slice_Type,
  @Agent_Code,
  @Event_Desc, 
--  @Status1,
  @Slice_Status,
  @Owner_Type,
  @Client_Sex,
  @Address1,
  @Address2,
  @Address3




declare @tcount int
declare @counter int
set @counter = 0

SELECT @tcount = (SELECT COUNT(*) FROM head_office_systems.dbo.Box_Tala)

while(@counter < @tcount)

Begin



set @color =''
--Temp table truncated each time, these are use in transaction processing
truncate table #TempB
truncate table #TempSw
--**********************************************************************

declare @statusDetail varchar(100)
select @statusDetail = description from Box_phase_3_codes where ID Like @status1


declare @slicereason varchar(100)
select @slicereason = description from Box_phase_3_codes where ID Like @SliceReasonCode

   if @Slice_Type = 'Indexation' begin
      set @increaseTypeFlag = 'I'
   end else begin
      set @increaseTypeFlag =''
   end

   set @slicereason = @Slice_Type


    if @policy_status = 'Lapsed' or @policy_status = 'Lapse' or @policy_status = 'Cancelled' begin
       set @status1 = 'Not in Force'
    end else begin
       set @status1 = @policy_status
    end

    set @statusDetail = @policy_status

/*
   if @status1 = 0 begin
      set @status2 = 'Application Status'
      end
   if @status1 = 10 begin
      set @status2 = 'In Force'
      end
      if @status1 > 19 and @status1 < 29 begin
      set @status2 = 'NPW'
      end
  
      if @status1 > 29  begin
      set @status2 = 'Not in Force'
      end

declare @RPA_Indicator2 varchar(20)

if @RPA_Indicator = 1 begin
   set @RPA_Indicator = 'Y'

end else begin
set @RPA_Indicator = 'N'
end


if @Rating_Indicator = 1 begin
   set @Rating_Indicator2 = 'Y'
   

end else begin
set @Rating_Indicator2 = 'N'

end
 

*/


--@SliceReasonCode
set @frequency = 'Monthly'
set @productcode ='Tala'
--************************POPULATE TEMP TABLE BEFORE UPDATE COLOR   **********************************--
--insert into #tempCommon(Policy_Number,CaseID, Clientforename, ClientSurname, ClientDOB, Postcode,Company_Code,product_code, sliceid, SliceReasonCode,Gross_Premium, Swift_Premium, term, Swift_Term, SumAssured, Old_Plan_Number, CommissionRate,AgentCode, SliceStartDate, increaseTypeFlag, frequency, status, DGT_Indicator, Status_Detail,  Rating_Indicator)
--values(@polnum,@CaseID,@Client_Forename, @Client_Surname,  cast(convert(datetime, @Client_DOB, 103)as datetime),  @Postcode,  @Company_Code,  @ProductCode, @slice_id,@slicereason, @Gross_Premium, @Swift_Premium, @term, @Swift_Term, @Sum_Assured, @Old_Plan_Number, @Commission_Rate, @Agent_Code, cast(convert(datetime, @Slice_Start_Date, 103)as datetime), @increaseTypeFlag, @frequency, @status2, @RPA_Indicator,@statusDetail,  @Rating_Indicator2)
--****************************************************************************************************--



insert into #tempCommon(Company_Code, Policy_Number,CaseID, product_code, Clientforename, ClientSurname, ClientDOB, Postcode, sliceid, SliceReasonCode,Gross_Premium, term, Swift_Term, SumAssured, Old_Plan_Number, CommissionRate,AgentCode, SliceStartDate, increaseTypeFlag, frequency, status, DGT_Indicator, Status_Detail,  Rating_Indicator, SliceEndDate, EventDesc, OwnerType, ClientSex, Address1, Address2, Address3, SliceStatus)
values(@Company_Code, @polnum,@CaseID, @ProductCode, @Client_Forename, @Client_Surname, @Client_DOB,  @Postcode,  @slice_id,@slicereason, @Gross_Premium, @term, @Swift_Term, @Sum_Assured, @Old_Plan_Number, @Commission_Rate, @Agent_Code, @Slice_Start_Date, @increaseTypeFlag, @frequency, @status1, @RPA_Indicator,@statusDetail,  @Rating_Indicator2, @Slice_End_Date, @Event_Desc, @Owner_Type, @Client_sex, @Address1, @Address2, @Address3, @Slice_Status)





set @counter = @counter + 1

declare @pol varchar(20)
--try to match on policy number
declare @caseidS varchar(10)

--First level of comparison begins here (policy number)
select @pol = cont_num from prod_zurich_openwork_datawarehouse.dbo.Box_TalaV where cont_num Like RTrim(@polnum)
if @@rowcount = 0 begin
--No match on policy number found try caseid

       --compare EN file case id against swift case id 
                      
               select @caseidS = policyref from prod_zurich_openwork_datawarehouse.dbo.Box_TalaV where policyref Like @caseid and @caseid <> null
    --if @@rowcount = 0 begin





--********************************************************************
               if @caseidS is null begin -- no caseid found on file
--********************************************************************


--***************************************************No match on policy number or Caseid, match on client details*************************************************************                                 
                                if @Client_Forename <> '' and @Client_Surname <> '' and @Client_DOB <> '' and @Postcode <> '' and @ProductCode <> '' begin
--****************************************************************************************************************************************************************************                            
                --Attempt to match on the following client details, need to convert date of birth to correct date format.                                       
                                           ---If a single match found highlight policy no. in blue.
                                         declare @cpol int --varchar(20) -- need to set DOB
                                         select @cpol = COUNT(cont_num) from prod_zurich_openwork_datawarehouse.dbo.Box_TalaV where FIRSTNAMES like @Client_Forename and Name like @Client_surname and Postcode like @Postcode and ProductCode = @ProductCode --and cast(convert(datetime, BIRTHDATE,112) as datetime) like cast(convert(datetime, @Client_DOB,112) as datetime)
                                         if @cpol = 1 begin
  
 --************************************************************************************
 --**************************Single Client found on Swift compare transaction *********
 --************************************************************************************
                                                                   

             declare @CommissionTypeDesc1 as varchar(50)
              select @CommissionTypeDesc1 = CommissionTypeDesc from prod_zurich_openwork_datawarehouse.dbo.Box_TalaV where cont_num Like RTrim(@polnum)
              
              update #TempCommon 
                  set Payment_Type = @CommissionTypeDesc1,
                  Swift_Payment_Type = @CommissionTypeDesc1
              where ClientForename like @Client_Forename and ClientSurname like @Client_Surname and Postcode like @Postcode and product_Code Like @ProductCode --and ClientDOB like @Client_DOB 


 
                --Dataset from the Zurich EN file for comparison File 1
                        insert into #TempB(Gross_Premium, Term, Slice_Start_Date, slice_id, Status)
                              select Gross_Premium, Slice_Term, Slice_Start_Date, Slice_Number, Slice_Status          
                  from head_office_systems.dbo.Box_Tala where Client_Forename like @Client_Forename and Client_Surname like @Client_Surname and Postcode like @Postcode --and Client_DOB like @Client_DOB-- and productCode Like @ProductCode



                 --Dataset from Swift for comparison File 2 -- need DOB
                        insert into #TempSw(Gross_Premium, Term, Slice_Start_Date, RPA_Indicator, TransactionNumber, TransType)
                            select Amount, TermYears, TransactionDate, SubsequentPurchase, TransactionNumber, TransType 
                  from prod_zurich_openwork_datawarehouse.dbo.Box_TalaV where FIRSTNAMES like @Client_Forename and Name like @Client_surname and Postcode like @Postcode --andcast(convert(datetime, BIRTHDATE,112) as datetime) like cast(convert(datetime, @Client_DOB,112) as datetime) --and ProductCode = @ProductCode
              
                        
              
                set @counter2 = 0
              
                SELECT @count = (SELECT COUNT(*) FROM #TempB)
              
                --Set up while loop to read each transaction and compare the values        
                while(@counter2 < @count)
                          Begin
              
                   SELECT @MinB = MIN(slice_id) FROM #TempB             
                               SELECT @MinS = MIN(transactionNumber) FROM #TempSw 
              

                  set @counter2 = @counter2 + 1
                          --select from the EN zurich file min Transactionnumber
              
              
                  set @color = ''
              
                          if @slice_id = @MinB begin
                                select
                    @gross = Gross_premium,
                                @trm   = Term,
                                @Slicedate = Slice_Start_Date,
                                @RPAInd    = RPA_Indicator,
                    @Status    = Status
                                from #TempB
                                Where slice_id = @MinB
              
                                  
                          --select from Swift file the min Transactionnumber
                              select
                    @Amount = Gross_premium,
                                 @trms   = Term,
                                @TransactionDate = Slice_Start_Date,
                                @SubsequentPurchase    = RPA_Indicator,
                    @TransactionNo = Transactionnumber,
                      @transtype = transtype
                              from #TempSw
                              Where TransactionNumber = @MinS

--***********************set transtype
       if @transtype = 1 or @transtype = 17 or @transtype = 23 begin
  set  @transtype2 = 'Active'        
       end

       if @transtype = 39 begin
  set  @transtype2 = 'Proposal'        
       end  
--********************
                  --Process store data comparison here and color code as necessary              
                       
                   if @gross = @Amount begin
        update #TempCommon 
        set Gross_Premium = @gross,
        Swift_Premium = @Amount 
        where policy_number = @polnum and sliceid = @slice_id
                   end else begin
        update #TempCommon 
        set Gross_Premium = '#'+@gross,-- +'(green)',
            Swift_Premium = @Amount,
            Change =  'GG'
        where policy_number = @polnum and sliceid = @slice_id
      set @color = @color + 'GG'
                  end


      if @trms = @trm begin
        set @trm = (@trm * 12)
        update #TempCommon 
        set Term = @trm,
                                  Swift_Term = @trms 
        where policy_number = @polnum
                end else begin
        set @trm = (@trm * 12)
        update #TempCommon        
        set Term = '#'+@trm,-- +'(green)',
             Swift_Term = @trms,
            Change =  @color + ' TG'
        where policy_number = @polnum and sliceid = @slice_id
      set @color = @color + ' TG'
                  end

        if(@RPAInd = 1)begin
          set @RPAInd = 'Y'
        end else begin
                                  set @RPAInd = 'N'
        end



                                   declare @d1 datetime     set @d1 = cast(convert(datetime, @TransactionDate, 112)as datetime)
                                   declare @d2 datetime     set @d2 = cast(convert(datetime, @Slicedate, 112)as datetime)
              
                                    if @d1 = @d2 begin
              --      if @TransactionDate = @Slicedate  begin
                      update #TempCommon 

--                      set SliceStartDate = convert(char(50), @d2, 112) --@Slicedate
                    set SliceStartDate = cast(convert(datetime, @Slicedate, 103)as datetime)
                      where policy_number = @polnum and sliceid = @slice_id
                                 end else begin
              --      set @pol = @polnum+'-non'
                        update #TempCommon 
                      --set SliceStartDate =  convert(char(8), @d2, 112), --+'(green)', --@Slicedate +'(green)'
                      set SliceStartDate = cast(convert(datetime, @Slicedate, 103)as datetime),
                          --Change =  @color + ' SG'
                        Change = 'SG'
                      where policy_number = @polnum and sliceid = @slice_id
                        set @color = @color + ' SG'
                                 end
              
              
                              --  If (@Status > 30) or (@Status > 19 and @Status < 29) begin
                                  --   update #TempCommon 
                      --set Status = '#'+@Status2,-- +'(green)',
                      --    Change =  @color + ' UG'
                      --where policy_number = @polnum and sliceid = @slice_id
                      --  set @color = @color + ' UG'
                              -- end
                    
              
                                  
                      update #TempCommon 
                      set policy_number = @polnum +'(blue)',
                                      Swift_transaction_no = @transactionno,
                          Swift_transaction_type  = @transtype2,
                          Change = 'SB'
                                                                                         where policy_number = @polnum
              
                       end ---- if @slice_id = @MinB
              
              
              
                            --delete record
                            delete from #tempB where slice_id = @MinB
                            delete from #tempSw where TransactionNumber = @MinS
              
                         End 
                         -- end loop
                                    

              end
--********************************************************************************************************
            end else begin ---- No matching policy found and set Payment_Type = indemnity*************
--********************************************************************************************************
                                                if cast(convert(datetime, @Slice_Start_Date, 112)as datetime) < cast(convert(datetime, @BeforeDate, 112)as datetime) begin
              update #TempCommon 
              set policy_number = @polnum, --+'(pink)',             
                                                            Payment_Type = 'IT'--,
                 -- Change = 'NP'
                                                          where policy_number = @polnum
               end else begin
                                                      update #TempCommon 
              set policy_number = @polnum +'(pink-)',             
                                                            Payment_Type = 'IT',
                  Change = 'NP'
                                                          where policy_number = @polnum

                                                   end
                                         
            end
               
--***********************************************************************************
--***********************End single client match found on Swift     *****************
--***********************************************************************************

 






--*****************************************************************************
               end else begin   --- case id found on file check for single case
--*****************************************************************************

                  declare @CommissionTypeDesc2 as varchar(50)
              select @CommissionTypeDesc2 = CommissionTypeDesc from prod_zurich_openwork_datawarehouse.dbo.Box_TalaV where cont_num Like RTrim(@polnum)   
              
              update #TempCommon 
                  set Payment_Type = @CommissionTypeDesc2,
                  Swift_Payment_Type = @CommissionTypeDesc2
              where caseid = @CaseID


  --if a single matching policy is found and swift policy number is not populated then compare transaction &
              --highlight policy number field in GREEEN on output spreadsheet.
                   declare @caseTOT int
            --SELECT @caseTOT = (SELECT COUNT(policyref) from zurich_openwork_datawarehouse.dbo.Box_ZurichV where policyref Like @caseid)
           SELECT @caseTOT = COUNT(policyref) from prod_zurich_openwork_datawarehouse.dbo.Box_TalaV where policyref Like @caseid
                   declare @pnum varchar(100)
                 select @pnum = cont_num from prod_zurich_openwork_datawarehouse.dbo.Box_TalaV where policyref Like @caseid           
                      if @caseTOT = 1 and @pnum = null begin 

 --************************************************************************************
 --**************************Single CaseID found on Swift compare transaction *********
 --************************************************************************************

                      --set so case never populated
          --Dataset from the Zurich EN file for comparison File 1
--                  insert into #TempB(Gross_Premium, Term, Slice_Start_Date, slice_id, Status)
--                    select Gross_Premium, Slice_Term, Slice_Start_Date, Slice_Number, Slice_Status          
--            from head_office_systems.dbo.Box_Tala where caseid = @CaseID--policy_number Like @polnum
        
        
          
           --Dataset from Swift for comparison File 2
--                  insert into #TempSw(Gross_Premium, Term, Slice_Start_Date, RPA_Indicator, TransactionNumber, TransType)
--                      select Amount, TermYears, TransactionDate, SubsequentPurchase, TransactionNumber, TransType 
--            from zurich_openwork_datawarehouse.dbo.Box_TalaV where policyref = @CaseID --cont_num Like @polnum         
        
                  
        
          set @counter2 = 0
        
          SELECT @count = (SELECT COUNT(*) FROM #TempB)
        
          --Set up while loop to read each transaction and compare the values        
          while(@counter2 < @count)
                    Begin
        
             SELECT @MinB = MIN(slice_id) FROM #TempB             
                         SELECT @MinS = MIN(transactionNumber) FROM #TempSw 
        
            set @counter2 = @counter2 + 1
                    --select from the EN zurich file min Transactionnumber
        
        
        
        set @color = ''
                    if @slice_id = @MinB begin
                          select
              @gross = Gross_premium,
                          @trm   = Term,
                          @Slicedate = Slice_Start_Date,
                          @RPAInd    = RPA_Indicator,
              @Status    = Status
                          from #TempB
                          Where slice_id = @MinB
        
                            
                    --select from Swift file the min Transactionnumber
                        select
              @Amount = Gross_premium,
                          @trms   = Term,
                          @TransactionDate = Slice_Start_Date,
                          @SubsequentPurchase    = RPA_Indicator,
                                                        @transactionno = transactionnumber,
                            @transtype = transtype
                        from #TempSw
                        Where TransactionNumber = @MinS

--**************************
if @transtype = 1 or @transtype = 17 or @transtype = 23 begin
  set  @transtype2 = 'Active'        
       end

       if @transtype = 39 begin
  set  @transtype2 = 'Proposal'        
       end  
--*******************************
            --Process store data comparison here and color code as necessary              
                       if @gross = @Amount begin
        update #TempCommon 
        set Gross_Premium = @gross,
        Swift_Premium = @Amount 
        where policy_number = @polnum and sliceid = @slice_id
                   end else begin
        update #TempCommon 
        set Gross_Premium = '#'+@gross,-- +'(green)',
            Swift_Premium = @Amount,
            Change =  'GG'
        where policy_number = @polnum and sliceid = @slice_id
      set @color = @color + 'GG'
                  end


      if @trms = @trm begin
        set @trm = (@trm * 12)
        update #TempCommon 
        set Term = @trm,
                                  Swift_Term = @trms 
        where policy_number = @polnum
                end else begin
        set @trm = (@trm * 12)
        update #TempCommon        
        set Term = '#'+@trm,-- +'(green)',
             Swift_Term = @trms,
            Change =  @color + ' TG'
        where policy_number = @polnum and sliceid = @slice_id
      set @color = @color + ' TG'
                  end

        if(@RPAInd = 1)begin
          set @RPAInd = 'Y'
        end else begin
                                  set @RPAInd = 'N'
        end

        
                             declare @d10 datetime     set @d10 = cast(convert(datetime, @TransactionDate, 112)as datetime)
                             declare @d20 datetime     set @d20 = cast(convert(datetime, @Slicedate, 112)as datetime)
        
                              if @d1 = @d2 begin
        --      if @TransactionDate = @Slicedate  begin
                update #TempCommon 
                --set SliceStartDate = convert(char(50), @d20, 112) --@Slicedate
                set SliceStartDate = cast(convert(datetime, @Slicedate, 103)as datetime)
                where policy_number = @polnum and sliceid = @slice_id
                           end else begin
        --      set @pol = @polnum+'-non'
                  update #TempCommon 
                --set SliceStartDate =  convert(char(8), @d20, 112), --+'(green)', --@Slicedate +'(green)'
              Set SliceStartDate = cast(convert(datetime, @Slicedate, 103)as datetime),
                      --Change =  @color + ' SG'
                 Change = 'SG'
                where policy_number = @polnum and sliceid = @slice_id
                    set @color = @color + ' SG'
                           end
        
        
                        --   If (@Status > 30) or (@Status > 19 and @Status < 29) begin
                          --     update #TempCommon 
                --set Status = '#'+@Status2,-- +'(green)',
                --    Change =  @color + ' UG'
                --where policy_number = @polnum and sliceid = @slice_id
                --  set @color = @color + ' UG'
                        -- end
              
        
                            
                update #TempCommon 
                set policy_number = '#'+@polnum, --+'(green)',
                Swift_transaction_no = @transactionno,
                        Swift_transaction_type  = @transtype2,
                              Change =   @color + ' PG'
                where CaseId = @caseId
                  set @color = @color + ' PG'
        
                 end ---- if @slice_id = @MinB
        
        
        
                      --delete record
                      delete from #tempB where slice_id = @MinB
                      delete from #tempSw where TransactionNumber = @MinS
        
                   End 
                   -- end loop
        
        
        --*Highlight pol num on table green and compare transaction

                   
                    end

               end -- else for case id found
--***********************************************************************************
--***********************End case id found on swift *********************************
--***********************************************************************************














--*****************************************************--
--*****************************************************--
end else begin --*Policy number found compare transaction
--******************************************************--
--*Comparing transaction for this policy               *--
--******************************************************--
--select count if same amount of transaction on EN and Swift


  declare @CommissionTypeDesc as varchar(50)
  select @CommissionTypeDesc = CommissionTypeDesc from prod_zurich_openwork_datawarehouse.dbo.Box_TalaV where cont_num Like RTrim(@polnum)   
  
  update #TempCommon 
      set Payment_Type = @CommissionTypeDesc,
      Swift_Payment_Type = @CommissionTypeDesc
  where policy_number = @polnum
    




  declare @ctransS int 
  select @ctransS = COUNT(cont_num) from prod_zurich_openwork_datawarehouse.dbo.Box_TalaV where cont_num Like RTrim(@polnum)

--select @ctransS

  declare @ctransBox int
  select @ctransBox = COUNT(policy_number) from head_office_systems.dbo.Box_Tala where policy_number Like RTrim(@polnum)

--select @ctransBox     

          -- Same amount of transaction(s) on EN and Swift
    if @ctransS = @ctransBox begin
          --***************************************************
    -- Same amount of transaction(s) on EN and Swift          
          --***************************************************       


          --Dataset from the Zurich EN file for comparison File 1
          insert into #TempB(Gross_Premium, Term, Slice_Start_Date, slice_id, Status)
            --  select Gross_Premium, Term, Slice_Start_Date, RPA_Indicator, slice_id, Status          
    select Gross_Premium, Slice_Term, Slice_Start_Date, Slice_Number, Slice_Status          
    from head_office_systems.dbo.Box_Tala where policy_number Like @polnum


   --Dataset from Swift for comparison File 2
          insert into #TempSw(Gross_Premium, Term, Slice_Start_Date, RPA_Indicator, TransactionNumber, TransType)
              select Amount, TermYears, TransactionDate, SubsequentPurchase, TransactionNumber, transtype 
    from prod_zurich_openwork_datawarehouse.dbo.Box_TalaV where cont_num Like RTrim(@polnum)         

          

  set @counter2 = 0

  SELECT @count = (SELECT COUNT(*) FROM #TempB)

  --Set up while loop to read each transaction and compare the values        
  while(@counter2 < @count)
            Begin

     SELECT @MinB = MIN(slice_id) FROM #TempB             
                 SELECT @MinS = MIN(transactionNumber) FROM #TempSw 

    set @counter2 = @counter2 + 1
            --select from the EN zurich file min Transactionnumber

declare @isSub int
set @isSub = 0
if (@counter2 = 1 and @SubsequentPurchase = '-1') begin
      set @isSub = 1
      update #TempCommon 
      set DGT_Indicator = 'Y'                          
      where policy_number = @polnum and sliceid = @MinB
                        set @Numsign ='#'
    end 


set @color = ''
-- Start date is before 31 jan 2006--************
            if @slice_id = @MinB and @isSub = 0 and cast(convert(datetime, @Slice_Start_Date, 112)as datetime) > cast(convert(datetime, @BeforeDate, 112)as datetime) begin
                  select
      @gross = Gross_premium,
                  @trm   = Term,
                  @Slicedate = Slice_Start_Date,
                  @RPAInd    = RPA_Indicator,
      @Status    = Status
                  from #TempB
                  Where slice_id = @MinB

                    
            --select from Swift file the min Transactionnumber
                select
      @Amount = Gross_premium,
                   @trms   = Term,
                  @TransactionDate = Slice_Start_Date,
                  @SubsequentPurchase    = RPA_Indicator,
                        @transactionno = transactionnumber,
                        @transtype = transtype

                from #TempSw
                Where TransactionNumber = @MinS


--**************************
if @transtype = 1 or @transtype = 17 or @transtype = 23 begin
  set  @transtype2 = 'Active'        
       end

       if @transtype = 39 begin
  set  @transtype2 = 'Proposal'        
       end  
--*******************************
    --Process store data comparison here and color code as necessary              
                   if @gross = @Amount begin

        update #TempCommon 
        set Gross_Premium = @gross,
        Swift_Premium = @Amount 
        where policy_number = @polnum and sliceid = @slice_id
                   end else begin
        update #TempCommon 
        set Gross_Premium = '#'+@gross,-- +'(green)',
            Swift_Premium = @Amount,
            Change =  'GG'
        where policy_number = @polnum and sliceid = @slice_id
      set @color = @color + 'GG'
                  end


      if @trms = @trm begin
        set @trm = (@trm * 12)
        update #TempCommon 
        set Term = @trm,
                                  Swift_Term = @trms 
        where policy_number = @polnum
                end else begin
        set @trm = (@trm * 12)
        update #TempCommon        
        set Term = '#'+@trm,-- +'(green)',
             Swift_Term = @trms,
            Change =  @color + ' TG'
        where policy_number = @polnum and sliceid = @slice_id
      set @color = @color + ' TG'
                  end

        if(@RPAInd = 1)begin
          set @RPAInd = 'Y'
        end else begin
                                  set @RPAInd = 'N'
        end
                                
  
      --Compare only on first transaction/slice. Assume match if EN RPA/DGT Ind ='Y' and Subsequent purchase = 1, or 
                  --or EN RPA/DGT Ind ='N' and Subsequent Purchase = 0
                   -- if (@counter2 = 1 and @RPAInd = 'Y' and @SubsequentPurchase = '-1') or (@counter2 = 1 and @RPAInd ='N' and (@SubsequentPurchase = 0 or @SubsequentPurchase is null or @SubsequentPurchase = '')) begin
        --update #TempCommon 
        --set DGT_Indicator = @RPAInd  
        --where policy_number = @polnum and sliceid = @slice_id
                  -- end else begin
                --          if @counter2 = 1 begin
      --  update #TempCommon 
        --set DGT_Indicator = '#'+@RPA_Indicator,--@RPAInd,-- +'(green)',
        --    Change =  @color + ' RG'
        --where policy_number = @polnum and sliceid = @slice_id
      --set @color = @color + ' RG'
                      --   end
                 -- end

     



                     declare @d11 datetime     set @d11 = cast(convert(datetime, @TransactionDate, 112)as datetime)

                     declare @d12 datetime     set @d12 = cast(convert(datetime, @Slicedate, 112)as datetime)

                      if @d11 = @d12 begin
--      if @TransactionDate = @Slicedate  begin
        update #TempCommon 
        --set SliceStartDate = convert(char(50), @d12, 112) --@Slicedate
          set SliceStartDate = cast(convert(datetime, @Slicedate, 103)as datetime)
        where policy_number = @polnum and sliceid = @slice_id
                   end else begin
--      set @pol = @polnum+'-non'
          update #TempCommon 
      --  set SliceStartDate =  convert(char(8), @d12, 112), --+'(green)', --@Slicedate +'(green)'
      set SliceStartDate = cast(convert(datetime, @Slicedate, 103)as datetime),
            --Change =  @color + ' SG'
         Change = 'SG'
        where policy_number = @polnum and sliceid = @slice_id
      set @color = @color + ' SG'
                   end


                 /*  If (@Status > 30) or (@Status > 19 and @Status < 29) begin
                       update #TempCommon 
        set Status = '#'+@Status2,-- +'(green)',
            Change =  @color + ' UG'
        where policy_number = @polnum and sliceid = @slice_id
      set @color = @color + ' UG'
                 end
      */



                              update #TempCommon
                                 set Swift_transaction_no = @transactionno,
             Swift_transaction_type  = @transtype2
                              where policy_number = @polnum and sliceid = @slice_id


         end ---- if @slice_id = @MinB



              --delete record
              delete from #tempB where slice_id = @MinB
              delete from #tempSw where TransactionNumber = @MinS

           End 
           -- end loop

  
         
--***********************************************************************************
--***********************End same number transaction on EN and Swift*****************
--***********************************************************************************










           
--******************************************************************************************************
          end else begin    --Different amount of transaction on EN and Swift
                            --Need to check which varible greater
--******************************************************************************************************
--select @ctransS        
--select @ctransbox
 -- set @pol = @polnum+'-non'
    if @ctransS > @ctransBox begin
                --***************************************************************
    --More tranasctions on Swift than on EN file - eg RPA removed
    --***************************************************************



  --Dataset from the Zurich EN file for comparison File 1
           insert into #TempB(Gross_Premium, Term, Slice_Start_Date, slice_id, Status)
           
    select Gross_Premium, Slice_Term, Slice_Start_Date, Slice_Number, Slice_Status          
    from head_office_systems.dbo.Box_Tala where policy_number Like @polnum
          


   --Dataset from Swift for comparison File 2
          insert into #TempSw(Gross_Premium, Term, Slice_Start_Date, RPA_Indicator, TransactionNumber, Transtype, paymenttype)
              select Amount, TermYears, TransactionDate, SubsequentPurchase, TransactionNumber, transtype, commissiontypedesc 
    from prod_zurich_openwork_datawarehouse.dbo.Box_TalaV where cont_num Like @polnum
      

               --  SELECT @MinB = MIN(slice_id) FROM #TempB             
               --  SELECT @MinS = MIN(transactionNumber) FROM #TempSw             
              

  set @counter2 = 0

  SELECT @count = (SELECT COUNT(*) FROM #TempSw)

  --Set up while loop to read each transaction and compare the values        
  while(@counter2 < @count)
            Begin

     SELECT @MinB = MIN(slice_id) FROM #TempB             
                 SELECT @MinS = MIN(transactionNumber) FROM #TempSw 

    set @counter2 = @counter2 + 1

             --****************************
           
              --****************************************************

             select
    @gross = Gross_premium,
                @trm   = Term,
                @Slicedate = Slice_Start_Date,
                @RPAInd    = RPA_Indicator,
                @Status    = Status
              from #TempB
              Where slice_id = @MinB

                    
            --select from Swift file the min Transactionnumber
              select
    @Amount = Gross_premium,
                @trms   = Term,
                @TransactionDate = Slice_Start_Date,
                @SubsequentPurchase    = RPA_Indicator,
                @transactionno = transactionnumber,
                @transtype = transtype,
                @paymenttype = paymenttype
              from #TempSw
              Where TransactionNumber = @MinS
  

--**************************
if @transtype = 1 or @transtype = 17 or @transtype = 23 begin
  set  @transtype2 = 'Active'        
       end

       if @transtype = 39 begin
  set  @transtype2 = 'Proposal'        
       end  
--*******************************

   --Additional row to EN file from swift transaction file                     
--          insert new row onto the EN file here and highlight in pink extracted from swift data

    if @count = @counter2 begin                 
                   declare @isondb varchar(20)
                    select @isondb = Policy_Number from #tempCommon where Policy_Number Like @polnum +'(Pink)'
                       if @isondb is null or @isondb =''begin
                insert into #tempCommon(Policy_Number, Swift_payment_type, swift_transaction_no, Swift_transaction_type, Swift_Premium, swift_term, change)  --,CaseID, Clientforename, ClientSurname, ClientDOB, Postcode,Company_Code,product_code)
      values(@polnum +'(Pink)', @paymenttype, @transactionno, @transtype2, @amount, @trms, 'NP') --,@CaseID,@Client_Forename, @Client_Surname,  @Client_DOB,  @Postcode,  @Company_Code,  @ProductCode)
                        end
                  Break
    end

--*******************************

declare @isSub2 int
set @isSub2 = 0
        if (@counter2 = 1 and @SubsequentPurchase = '-1') begin
      set @isSub2 = 1
      update #TempCommon 
      set DGT_Indicator = 'Y'                     
      where policy_number = @polnum and sliceid = @MinB
         end 

set @color = ''

  if @slice_id = @MinB and @isSub2 = 0 and cast(convert(datetime, @Slice_Start_Date, 112)as datetime) > cast(convert(datetime, @BeforeDate, 112)as datetime) begin
    --Process store data comparison here and color code as necessary              
                 if @gross = @Amount begin
      update #TempCommon 
      set --Gross_Premium = @gross,--@Amount,
      Swift_Premium = @Amount 
      where policy_number = @polnum and sliceid = @slice_id
                 end else begin
      update #TempCommon 
      set Gross_Premium = '#'+@gross,-- +'(green)',
          Swift_Premium = @Amount,
            Change = 'GG'
      where policy_number = @polnum and sliceid = @slice_id
      set @color = 'GG'

                 end


    if @trms = @trm begin
      set @trm = (@trm * 12)
      update #TempCommon    
      set Term = @trm,
      Swift_Term = @trms 
      where policy_number = @polnum and sliceid = @slice_id
                 end else begin
      set @trm = (@trm * 12)
      update #TempCommon 
      set Term = '#'+@trm,-- +'(green)',
          Swift_Term = @trms,
            Change = @color + ' TG'
      where policy_number = @polnum and sliceid = @slice_id
      set @color = @color + ' TG'
                 end
  

        if(@RPAInd = 1)begin
          set @RPAInd = 'Y'
        end else begin
                                  set @RPAInd = 'N'
        end
    --Compare only on first transaction/slice. Assume match if EN RPA/DGT Ind ='Y' and Subsequent purchase = 1, or 
                --or EN RPA/DGT Ind ='N' and Subsequent Purchase = 0
               --   if (@counter2 = 1 and @RPAInd = 'Y' and @SubsequentPurchase = '-1') or (@counter2 = 1 and @RPAInd ='N' and (@SubsequentPurchase = 0 or @SubsequentPurchase is null or @SubsequentPurchase = '')) begin
    --  update #TempCommon 
    --  set DGT_Indicator = @RPAInd  
    --  where policy_number = @polnum and sliceid = @slice_id
               --  end else begin
                --        if @counter2 = 1 begin
      --update #TempCommon 
      --set DGT_Indicator = '#'+@RPA_Indicator,--@RPAInd, --+'(green)',
      --      Change =  @color + ' RG'
      --where policy_number = @polnum and sliceid = @slice_id
      --set @color = @color + ' RG'
                     --   end
              --   end


     


    
           declare @dbox1 datetime     set @dbox1 = cast(convert(datetime, @TransactionDate, 112)as datetime)
                     declare @dbox2 datetime     set @dbox2 = cast(convert(datetime, @Slicedate, 112)as datetime)

                      if @dbox1 = @dbox2 begin
--      if @TransactionDate = @Slicedate  begin
        update #TempCommon 
        --set SliceStartDate = convert(char(50), @dbox2, 112) --@Slicedate
        set SliceStartDate = cast(convert(datetime, @Slicedate, 103)as datetime)
        where policy_number = @polnum and sliceid = @slice_id
                   end else begin
--      set @pol = @polnum+'-non'
          update #TempCommon 
--        set SliceStartDate =   convert(char(8), @dbox2, 112), --+'(green)', --@Slicedate +'(green)'
      set SliceStartDate = cast(convert(datetime, @Slicedate, 103)as datetime),
          --  Change =  @color + ' SG'
         Change = 'SG'
        where policy_number = @polnum and sliceid = @slice_id
      set @color = @color + ' SG'
                   end


               --  If (@Status > 30) or (@Status > 19 and @Status < 29) begin
                 --   update #TempCommon 
    --  set Status = '#'+@Status2, --+'(green)',
      --      Change =  @color + ' UG'
    --  where policy_number = @polnum
    --  set @color = @color + ' UG'
               --  end
    

        update #TempCommon
                                     set Swift_transaction_no = @transactionno,
             Swift_transaction_type  = @transtype2
                               where policy_number = @polnum and sliceid = @slice_id


         end ----- @slice_id = @Minb

              --delete record
              delete from #tempB where slice_id = @MinB
              delete from #tempSw where TransactionNumber = @MinS

           End 
           -- end loop
                   
--***********************************************************************************
--***********************End RPA removed on ESwift **********************************
--***********************************************************************************

--set @pol = @pol+'-G'

              


 

--***************************************************************************************************
                end else begin  -- Transaction processing 
--***************************************************************************************************
--More transactions on EN file than on Swift - eg Increase/RPA:
--***************************************************************************************************


         --Dataset from the Zurich EN file for comparison File 1
          insert into #TempB(Gross_Premium, Term, Slice_Start_Date, slice_id, Status)
             -- select Gross_Premium, Term, Slice_Start_Date, RPA_Indicator, slice_id, Status   
     select Gross_Premium, Slice_Term, Slice_Start_Date, Slice_Number, Slice_Status                 

    from head_office_systems.dbo.Box_Tala where policy_number Like @polnum

   --Dataset from Swift for comparison File 2

  
           -- Insert into Swift file only transaction number greater than box file assuming slice cannot have same number e.g 1:1
          insert into #TempSw(Gross_Premium, Term, Slice_Start_Date, RPA_Indicator, TransactionNumber, transType)
              select Amount, TermYears, TransactionDate, SubsequentPurchase, TransactionNumber, transtype 
--********************************Possible miss transaction if both Box and Swift has same transaction number **************
    from prod_zurich_openwork_datawarehouse.dbo.Box_TalaV where cont_num Like RTrim(@polnum) --and TransactionNumber >= @slice_id          
--*****************************

  set @counter2 = 0

           -- Pick from Swift file only transaction number greater than box file assuming slice cannot have same number e.g 1:1
--********************************Possible miss transaction if both Box and Swift has same transaction number **************
         --select @count = (select count(*) from #tempSw where TransactionNumber >= @slice_id)
      select @count = (select count(*) from #tempB)
--****************************
         ---*****Make out row yellow if no transaction found potential problem where Box file and Swift has same transaction /sliceid value
                
          --********************************************************************
    --Set up while loop to read each transaction and compare the values        
  while(@counter2 < @count)
            Begin



                 



--          set @MinB = @Slice_id
     SELECT @MinB =  MIN(Slice_id) FROM #TempB
                SELECT @MinS = MIN(transactionNumber) FROM #TempSw 
    set @counter2 = @counter2 + 1



    if @MinS is null begin
     update #TempCommon 
      set policy_number = @polnum +'(yellow)',
       Change = 'TY'
      where policy_number = @polnum and sliceid = @MinB--@slice_id                                           
                 end
            --select from the EN zurich file min Transactionnumber

             select
    @gross = Gross_premium,
                @trm   = Term,
                @Slicedate = Slice_Start_Date,
                @RPAInd    = RPA_Indicator,
                @Status    = Status
              from #TempB
              Where slice_id = @MinB

                    
            --select from Swift file the min Transactionnumber
              select
    @Amount = Gross_premium,
                @trms   = Term,
                @TransactionDate = Slice_Start_Date,
                @SubsequentPurchase    = RPA_Indicator,
                @transactionno = transactionnumber,
                @transtype = transtype
              from #TempSw
              Where TransactionNumber = @MinS
  

--**************************
if @transtype = 1 or @transtype = 17 or @transtype = 23 begin
  set  @transtype2 = 'Active'        
       end

       if @transtype = 39 begin
  set  @transtype2 = 'Proposal'        
       end  
--*******************************
--declare @isSub int
 set @isSub = 0
if (@counter2 = 1 and @SubsequentPurchase = '-1') begin 
      set @isSub = 1
      update #TempCommon 
      set DGT_Indicator = 'Y'                         
      where policy_number = @polnum and sliceid = @MinB                         
                 end

set @color = ''
   if @slice_id = @MinB and @isSub = 0 and cast(convert(datetime, @Slice_Start_Date, 112)as datetime) > cast(convert(datetime, @BeforeDate, 112)as datetime) begin
    --Process store data comparison here and color code as necessary              
                 if @gross = @Amount begin
      update #TempCommon 
      set --Gross_Premium = @gross,   --amount,
      Swift_Premium = @Amount 
      where policy_number = @polnum and sliceid = @MinB
                 end else begin
      update #TempCommon 
      set Gross_Premium = '#'+@gross,-- +'(green)',
          Swift_Premium = @Amount,
            Change =  'GG'
      where policy_number = @polnum and sliceid = @MinB
      set @color = 'GG'
                 end



    if @trms = @trm begin
                        set @trm = (@trm * 12)
      update #TempCommon 
      set Term = (@trm),
                        Swift_Term = @trms 
      where policy_number = @polnum and sliceid = @MinB
                 end else begin 
                         set @trm = (@trm * 12)
      update #TempCommon 
      set Term = '#'+(@trm),-- +'(green)',
                           Swift_Term = @trms,
            Change =  @color + ' TG'
      where policy_number = @polnum and sliceid = @MinB
      set @color = @color + ' TG'
                 end
  

        if(@RPAInd = 1)begin
          set @RPAInd = 'Y'
        end else begin
                                  set @RPAInd = 'N'
        end

    --Compare only on first transaction/slice. Assume match if EN RPA/DGT Ind ='Y' and Subsequent purchase = 1, or 
                --or EN RPA/DGT Ind ='N' and Subsequent Purchase = 0
                 
                  --or (@counter2 = 1 and @RPAInd ='N' and (@SubsequentPurchase = 0 or @SubsequentPurchase is null or @SubsequentPurchase = '')) begin

                
      
                
      

         declare @dbx1 datetime     set @dbx1 = cast(convert(datetime, @TransactionDate, 112)as datetime)
                     declare @dbx2 datetime     set @dbx2 = cast(convert(datetime, @Slicedate, 112)as datetime)

                      if @dbx1 = @dbx2 begin
--      if @TransactionDate = @Slicedate  begin
        update #TempCommon 
      --  set SliceStartDate = convert(char(50), @dbx2, 112) --@Slicedate
      set SliceStartDate = cast(convert(datetime, @Slicedate, 103)as datetime)
        where policy_number = @polnum and sliceid = @slice_id
                   end else begin
--      set @pol = @polnum+'-non'
          update #TempCommon 
      --  set SliceStartDate =  convert(char(8), @dbx2, 112), -- +'(green)', --@Slicedate +'(green)'
        set SliceStartDate = cast(convert(datetime, @Slicedate, 103)as datetime),
            --Change =  @color + ' SG'
           Change = 'SG'
        where policy_number = @polnum and sliceid = @slice_id
      set @color = @color + ' SG'
                   end




               /*  If (@Status > 30) or (@Status > 19 and @Status < 29) begin
                    update #TempCommon 
      set Status = '#'+@Status2, --+'(green)',
            Change =  @color + ' UG'
      where policy_number = @polnum
      set @color = @color + ' UG'
                 end
    */


        update #TempCommon
                                     set Swift_transaction_no = @transactionno,
             Swift_transaction_type  = @transtype2
                               where policy_number = @polnum and sliceid = @slice_id

  end

              --delete record
              delete from #tempB where slice_id = @MinB
              delete from #tempSw where TransactionNumber = @MinS

           End 
           -- end loop

          
                 

--***********************************************************************************
--***********************End Increase/RPA on EN *************************************
--***********************************************************************************                 
 
                end



          end
  




--****************************************************************
--End Transaction processing
--****************************************************************

--**Temp populating table, need to be removed
set @pol = @pol+'-G'
--insert into #tempCommon(Policy_Number,CaseID, Clientforename, ClientSurname, ClientDOB, Postcode,Company_Code,product_code)
--values(@pol,@CaseID,@Client_Forename, @Client_Surname,  @Client_DOB,  @Postcode,  @Company_Code,  @ProductCode)
--*********************
end


--If the first Swift transaction for a policy contains -1 in the subsequent purchase field, then all other rows for that 
--policy should contain a '#'
declare @isYes varchar(20)
select @isYes = policy_number from #tempCommon where policy_number = @polnum and DGT_Indicator = 'Y'
update #TempCommon 
set DGT_Indicator = '#'
where policy_number = @isYes and (DGT_Indicator is null or DGT_Indicator = '')



fetch policy_cursor
into
  @polnum, 
  @Client_Forename,
  @Client_Surname,
  @Client_DOB,
  @Postcode,
  @Company_Code, 
  @Slice_id,
  @Slice_Start_Date,
  @Slice_End_Date,
  @Gross_Premium,
  @term,
  @Sum_Assured,
  @Policy_Status,
  @Slice_Type,
  @Agent_Code,
  @Event_Desc, 
--  @Status1,
  @Slice_Status,
  @Owner_Type,
  @Client_Sex,
  @Address1,
  @Address2,
  @Address3
 
end


close policy_cursor
deallocate policy_cursor


--select *

--from #tempCommon



truncate table tala_common_it
truncate table tala_common_nonit

insert into tala_common_it (policy_number, Case_ID, Clientforename,Clientsurname, Postcode,Company_Code,product_code, slice_id, SliceReasonCode,Gross_Premium, Swift_Premium, term, Swift_Term, Sum_Assured, Old_plan_indictator, CommissionRate,AgentCode, issuedate, SliceStartDate, increaseTypeFlag, frequency, status, DGT_Indicator, Payment_Type, Swift_Payment_Type,Swift_Transaction_No, swift_transaction_type,Status_detail,Rating_Indicator, SliceEndDate, EventDesc, OwnerType, ClientSex, Address1, Address2, Address3,SliceStatus,ClientDOB, Change) 
select policy_number, caseid, Clientforename,Clientsurname, postcode, company_code, product_code, sliceid, SliceReasonCode,Gross_Premium, Swift_Premium, term, Swift_Term, SumAssured, Old_Plan_Number,CommissionRate,AgentCode, issuedate, SliceStartDate, increaseTypeFlag, frequency, status, DGT_Indicator,Payment_Type, Swift_Payment_Type,Swift_transaction_no, swift_transaction_type,Status_detail, Rating_Indicator, SliceEndDate, EventDesc, OwnerType, ClientSex, Address1, Address2, Address3, SliceStatus,ClientDOB, Change --Amount, TermYears, TransactionDate, SubsequentPurchase, TransactionNumber, TransType 
from #tempCommon --zurich_openwork_datawarehouse.dbo.Box_ZurichV where cast(convert(datetime, BIRTHDATE,112) as datetime) like cast(convert(datetime, @Client_DOB,112) as datetime) and FIRSTNAMES like @Client_Forename and Name like @Client_surname and Postcode like @Postcode and ProductCode = @ProductCode
where Payment_Type like 'Indemnity' or Swift_Payment_Type like 'Indemnity'
order by policy_number, sliceid


insert into tala_common_nonit (policy_number, Case_ID, Clientforename,Clientsurname, Postcode,Company_Code,product_code, slice_id, SliceReasonCode,Gross_Premium, Swift_Premium, term, Swift_Term, Sum_Assured, Old_plan_indictator, CommissionRate,AgentCode, issuedate, SliceStartDate, increaseTypeFlag, frequency, status, DGT_Indicator, Payment_Type, Swift_Payment_Type,Swift_Transaction_No, swift_transaction_type,Status_detail,Rating_Indicator, SliceEndDate, EventDesc, OwnerType, ClientSex, Address1, Address2, Address3, SliceStatus, ClientDOB, Change) 
select policy_number, caseid, Clientforename, Clientsurname, postcode, company_code, product_code, sliceid, SliceReasonCode,Gross_Premium, Swift_Premium, term, Swift_Term, SumAssured, Old_Plan_Number,CommissionRate,AgentCode, issuedate, SliceStartDate, increaseTypeFlag, frequency, status, DGT_Indicator,Payment_Type, Swift_Payment_Type,Swift_transaction_no, swift_transaction_type,Status_detail, Rating_Indicator, SliceEndDate, EventDesc, OwnerType, ClientSex, Address1, Address2, Address3, SliceStatus, ClientDOB, Change --Amount, TermYears, TransactionDate, SubsequentPurchase, TransactionNumber, TransType 
from #tempCommon --zurich_openwork_datawarehouse.dbo.Box_ZurichV where cast(convert(datetime, BIRTHDATE,112) as datetime) like cast(convert(datetime, @Client_DOB,112) as datetime) and FIRSTNAMES like @Client_Forename and Name like @Client_surname and Postcode like @Postcode and ProductCode = @ProductCode
where (Payment_Type is null and swift_Payment_Type <>'Indemnity') or Payment_Type <> 'Indemnity'
order by policy_number, sliceid


/*
truncate table zurich_common_nonit

select *
 -- into zurich_common
from #tempCommon

--Policy_Number,CaseID, Clientforename, ClientSurname, ClientDOB, Postcode,Company_Code,product_code, sliceid, SliceReasonCode,Gross_Premium, Swift_Premium, term, Swift_Term, SumAssured, Old_Plan_Number, CommissionRate,AgentCode, issuedate, SliceStartDate, increaseTypeFlag, frequency, status, DGT_Indicator
--*** remove ClientDOB field not populated
--*** insert into two seperate files for IT and Non IT files** Name the tables Zurich_IT_Common, Zurich_NonIT_Common
insert into zurich_common_it (policy_number, Case_ID, Clientforename, Postcode,Company_Code,product_code, slice_id, SliceReasonCode,Gross_Premium, Swift_Premium, term, Swift_Term, Sum_Assured, Old_plan_indictator, CommissionRate,AgentCode, issuedate, SliceStartDate, increaseTypeFlag, frequency, status, DGT_Indicator, Payment_Type, Swift_Payment_Type,Swift_Transaction_No, swift_transaction_type,Status_detail,Rating_Indicator, Change) 
select policy_number, caseid, Clientforename, postcode, company_code, product_code, sliceid, SliceReasonCode,Gross_Premium, Swift_Premium, term, Swift_Term, SumAssured, Old_Plan_Number,CommissionRate,AgentCode, issuedate, SliceStartDate, increaseTypeFlag, frequency, status, DGT_Indicator,Payment_Type, Swift_Payment_Type,Swift_transaction_no, swift_transaction_type,Status_detail, Rating_Indicator, Change --Amount, TermYears, TransactionDate, SubsequentPurchase, TransactionNumber, TransType 
from #tempCommon --zurich_openwork_datawarehouse.dbo.Box_ZurichV where cast(convert(datetime, BIRTHDATE,112) as datetime) like cast(convert(datetime, @Client_DOB,112) as datetime) and FIRSTNAMES like @Client_Forename and Name like @Client_surname and Postcode like @Postcode and ProductCode = @ProductCode
where Payment_Type like 'Indemnity' or Swift_Payment_Type like 'Indemnity'

insert into zurich_common_nonit (policy_number, Case_ID, Clientforename, Postcode,Company_Code,product_code, slice_id, SliceReasonCode,Gross_Premium, Swift_Premium, term, Swift_Term, Sum_Assured, Old_plan_indictator, CommissionRate,AgentCode, issuedate, SliceStartDate, increaseTypeFlag, frequency, status, DGT_Indicator, Payment_Type, Swift_Payment_Type,Swift_Transaction_No, swift_transaction_type,Status_detail,Rating_Indicator, Change) 
select policy_number, caseid, Clientforename, postcode, company_code, product_code, sliceid, SliceReasonCode,Gross_Premium, Swift_Premium, term, Swift_Term, SumAssured, Old_Plan_Number,CommissionRate,AgentCode, issuedate, SliceStartDate, increaseTypeFlag, frequency, status, DGT_Indicator,Payment_Type, Swift_Payment_Type,Swift_transaction_no, swift_transaction_type,Status_detail,Rating_Indicator, Change --Amount, TermYears, TransactionDate, SubsequentPurchase, TransactionNumber, TransType 
from #tempCommon --zurich_openwork_datawarehouse.dbo.Box_ZurichV where cast(convert(datetime, BIRTHDATE,112) as datetime) like cast(convert(datetime, @Client_DOB,112) as datetime) and FIRSTNAMES like @Client_Forename and Name like @Client_surname and Postcode like @Postcode and ProductCode = @ProductCode
where (Payment_Type is null and swift_Payment_Type <>'Indemnity') or Payment_Type <> 'Indemnity'

*/


drop table #tempCommon


drop Table #TempB
drop Table #TempSw







































GO
/****** Object:  StoredProcedure [dbo].[box_Tala_view]    Script Date: 7/3/2026 3:44:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO














CREATE              PROCEDURE [dbo].[box_Tala_view]
AS


truncate table Box_TALAV
/*
declare policy_cursor cursor
for
 select distinct 
    [Policy_Number]

from head_office_systems.dbo.Box_Tala
 for read only

declare
  @polnum                 varchar(20)

open policy_cursor
fetch policy_cursor
into
  @polnum



while (@@fetch_status = 0)
   begin
*/

insert into Box_TALAV(ID, PolicyID, TransactionNumber, TransType, CommissionTypeDesc, ProductProviderCode,Amount,TermYears, TermMonths, TransactionDate, AdminMethod, SubsequentPurchase, CodeCommissionShapeID, ProposalDate, 
                      Frequency, CommRenewalFrequency, FIRSTNAMES, NAME, BIRTHDATE, POSTCODE, ProductCode, CONT_NUM, 
                      PolicyRef, WrittenTranID) 
SELECT  pt.ID, pt.PolicyID, pt.TransactionNumber, pt.TransType, pt.CommissionTypeDesc, pt.ProductProviderCode, pt.Amount, 
                      pt.TermYears, pt.TermMonths, pt.TransactionDate, pt.AdminMethod, pt.SubsequentPurchase, pt.CodeCommissionShapeID, pt.ProposalDate, 
                      pt.Frequency, pt.CommRenewalFrequency, c.FIRSTNAMES, c.NAME, c.BIRTHDATE, c.POSTCODE, pol.ProductCode, pol.CONT_NUM, 
                      pol.PolicyRef, pt.writtentranid
FROM         dbo.mstt_PolicyTransactions pt LEFT OUTER JOIN
                      dbo.msit_S_POLMAI pol ON pt.PolicyID = pol.POL_NUM LEFT OUTER JOIN
                      dbo.mstt_Clients c ON pol.CLIENT_NUM = c.CLIENT_NUM
WHERE     (pt.ProductProviderCode LIKE 'Zurich New' OR

                          
                             pt.ProductProviderCode LIKE 'Zurich New') AND (pol.ProductCode Like 'TALA') AND (pt.TransType IN (1, 17, 23)) and (pt.transtypedesc <>'proposal'or(pt.transtypedesc like 'proposal' and pt.id <> '' and pt.issuedtranid is null)or  pt.writtentranid <> pt.id) 
        --and pol.cont_num = @polnum


ORDER BY pt.PolicyID, pt.TransactionNumber

--fetch policy_cursor
--into
 -- @polnum

--end


--close policy_cursor
--deallocate policy_cursor





GO
/****** Object:  StoredProcedure [dbo].[box_zurich_montly_view]    Script Date: 7/3/2026 3:44:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



CREATE        PROCEDURE [dbo].[box_zurich_montly_view]
AS


truncate table Box_ZurichMV

declare policy_cursor cursor
for
 select distinct 
    [Policy_Number]

from head_office_systems.dbo.Box_Zurich_monthly
 for read only

declare
  @polnum                 varchar(20)

open policy_cursor
fetch policy_cursor
into
  @polnum



while (@@fetch_status = 0)
   begin


insert into Box_ZurichMV(ID, PolicyID, TransactionNumber, TransType, CommissionTypeDesc, ProductProviderCode,Amount,TermYears, TermMonths, TransactionDate, AdminMethod, SubsequentPurchase, CodeCommissionShapeID, ProposalDate, 
                      Frequency, CommRenewalFrequency, FIRSTNAMES, NAME, BIRTHDATE, POSTCODE, ProductCode, CONT_NUM, 
                      PolicyRef, WrittenTranID) 
SELECT  pt.ID, pt.PolicyID, pt.TransactionNumber, pt.TransType, pt.CommissionTypeDesc, pt.ProductProviderCode, pt.Amount, 
                      pt.TermYears, pt.TermMonths, pt.TransactionDate, pt.AdminMethod, pt.SubsequentPurchase, pt.CodeCommissionShapeID, pt.ProposalDate, 
                      pt.Frequency, pt.CommRenewalFrequency, c.FIRSTNAMES, c.NAME, c.BIRTHDATE, c.POSTCODE, pol.ProductCode, pol.CONT_NUM, 
                      pol.PolicyRef, pt.writtentranid
FROM         dbo.mstt_PolicyTransactions pt LEFT OUTER JOIN
                      dbo.msit_S_POLMAI pol ON pt.PolicyID = pol.POL_NUM LEFT OUTER JOIN
                      dbo.mstt_Clients c ON pol.CLIENT_NUM = c.CLIENT_NUM
WHERE     (pt.ProductProviderCode LIKE 'Zurich New' OR
--                      pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null))  and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and (select count(policyid) from mstt_PolicyTransactions)=1))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
--                        pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null and (select count(policyid) from mstt_PolicyTransactions where pt.policyid = pt.policyid)=1 )) -- and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and (select count(policyid) from mstt_PolicyTransactions)=1))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
                      --  pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null))  and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
                      --  pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null) or (pt.id <> '' and pt.transtypedesc <>'proposal'))  and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
                            pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and (pt.transtypedesc <>'proposal'or(pt.transtypedesc like 'proposal' and pt.id <> '' and pt.issuedtranid is null)or  pt.writtentranid <> pt.id) --and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null) or (pt.id <> '' and pt.transtypedesc <>'proposal'))  and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
                                  -- and pt.ID = pt.issuedTranID or (pt.id <> null and pt.issuedtransid is null))
                    --AND (pt.IssuedTranID IS NULL OR
                     -- pt.IssuedTranID NOT IN
                       --   (SELECT DISTINCT transactionid
                         --   FROM          mstt_Expectation)) AND (pt.TransType IN (1, 17, 23, 39))

      and pol.cont_num = @polnum                     

ORDER BY pt.PolicyID, pt.TransactionNumber

fetch policy_cursor
into
  @polnum

end


close policy_cursor
deallocate policy_cursor


/*truncate table Box_ZurichV

insert into Box_ZurichV(ID, PolicyID, TransactionNumber, TransType, CommissionTypeDesc, ProductProviderCode,Amount,TermYears, TermMonths, TransactionDate, AdminMethod, SubsequentPurchase, CodeCommissionShapeID, ProposalDate, 
                      Frequency, CommRenewalFrequency, FIRSTNAMES, NAME, BIRTHDATE, POSTCODE, ProductCode, CONT_NUM, 
                      PolicyRef, WrittenTranID) 
SELECT  pt.ID, pt.PolicyID, pt.TransactionNumber, pt.TransType, pt.CommissionTypeDesc, pt.ProductProviderCode, pt.Amount, 
                      pt.TermYears, pt.TermMonths, pt.TransactionDate, pt.AdminMethod, pt.SubsequentPurchase, pt.CodeCommissionShapeID, pt.ProposalDate, 
                      pt.Frequency, pt.CommRenewalFrequency, c.FIRSTNAMES, c.NAME, c.BIRTHDATE, c.POSTCODE, pol.ProductCode, pol.CONT_NUM, 
                      pol.PolicyRef, pt.writtentranid
FROM         dbo.mstt_PolicyTransactions pt LEFT OUTER JOIN
                      dbo.msit_S_POLMAI pol ON pt.PolicyID = pol.POL_NUM LEFT OUTER JOIN
                      dbo.mstt_Clients c ON pol.CLIENT_NUM = c.CLIENT_NUM
WHERE     (pt.ProductProviderCode LIKE 'Zurich New' OR
--                      pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null))  and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and (select count(policyid) from mstt_PolicyTransactions)=1))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
--                        pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null and (select count(policyid) from mstt_PolicyTransactions where pt.policyid = pt.policyid)=1 )) -- and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and (select count(policyid) from mstt_PolicyTransactions)=1))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
                      --  pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null))  and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
                      --  pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null) or (pt.id <> '' and pt.transtypedesc <>'proposal'))  and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
                            pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and (pt.transtypedesc <>'proposal'or(pt.transtypedesc like 'proposal' and pt.id <> '' and pt.issuedtranid is null)or  pt.writtentranid <> pt.id) --and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null) or (pt.id <> '' and pt.transtypedesc <>'proposal'))  and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
                                  -- and pt.ID = pt.issuedTranID or (pt.id <> null and pt.issuedtransid is null))
                    --AND (pt.IssuedTranID IS NULL OR
                     -- pt.IssuedTranID NOT IN
                       --   (SELECT DISTINCT transactionid
                         --   FROM          mstt_Expectation)) AND (pt.TransType IN (1, 17, 23, 39))
ORDER BY pt.PolicyID, pt.TransactionNumber
*/

GO
/****** Object:  StoredProcedure [dbo].[box_zurich_view]    Script Date: 7/3/2026 3:44:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO


CREATE        PROCEDURE [dbo].[box_zurich_view]
AS


truncate table Box_ZurichV

declare policy_cursor cursor
for
 select distinct 
    [Policy_Number]

from head_office_systems.dbo.Box_Zurich
 for read only

declare
  @polnum                 varchar(20)

open policy_cursor
fetch policy_cursor
into
  @polnum



while (@@fetch_status = 0)
   begin


insert into Box_ZurichV(ID, PolicyID, TransactionNumber, TransType, CommissionTypeDesc, ProductProviderCode,Amount,TermYears, TermMonths, TransactionDate, AdminMethod, SubsequentPurchase, CodeCommissionShapeID, ProposalDate, 
                      Frequency, CommRenewalFrequency, FIRSTNAMES, NAME, BIRTHDATE, POSTCODE, ProductCode, CONT_NUM, 
                      PolicyRef, WrittenTranID) 
SELECT  pt.ID, pt.PolicyID, pt.TransactionNumber, pt.TransType, pt.CommissionTypeDesc, pt.ProductProviderCode, pt.Amount, 
                      pt.TermYears, pt.TermMonths, pt.TransactionDate, pt.AdminMethod, pt.SubsequentPurchase, pt.CodeCommissionShapeID, pt.ProposalDate, 
                      pt.Frequency, pt.CommRenewalFrequency, c.FIRSTNAMES, c.NAME, c.BIRTHDATE, c.POSTCODE, pol.ProductCode, pol.CONT_NUM, 
                      pol.PolicyRef, pt.writtentranid
FROM         dbo.mstt_PolicyTransactions pt LEFT OUTER JOIN
                      dbo.msit_S_POLMAI pol ON pt.PolicyID = pol.POL_NUM LEFT OUTER JOIN
                      dbo.mstt_Clients c ON pol.CLIENT_NUM = c.CLIENT_NUM
WHERE     (pt.ProductProviderCode LIKE 'Zurich New' OR
--                      pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null))  and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and (select count(policyid) from mstt_PolicyTransactions)=1))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
--                        pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null and (select count(policyid) from mstt_PolicyTransactions where pt.policyid = pt.policyid)=1 )) -- and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and (select count(policyid) from mstt_PolicyTransactions)=1))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
                      --  pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null))  and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
                      --  pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null) or (pt.id <> '' and pt.transtypedesc <>'proposal'))  and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
                            pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and (pt.transtypedesc <>'proposal'or(pt.transtypedesc like 'proposal' and pt.id <> '' and pt.issuedtranid is null)or  pt.writtentranid <> pt.id) --and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null) or (pt.id <> '' and pt.transtypedesc <>'proposal'))  and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
                                  -- and pt.ID = pt.issuedTranID or (pt.id <> null and pt.issuedtransid is null))
                    --AND (pt.IssuedTranID IS NULL OR
                     -- pt.IssuedTranID NOT IN
                       --   (SELECT DISTINCT transactionid
                         --   FROM          mstt_Expectation)) AND (pt.TransType IN (1, 17, 23, 39))

      and pol.cont_num = @polnum                     

ORDER BY pt.PolicyID, pt.TransactionNumber

fetch policy_cursor
into
  @polnum

end


close policy_cursor
deallocate policy_cursor


/*truncate table Box_ZurichV

insert into Box_ZurichV(ID, PolicyID, TransactionNumber, TransType, CommissionTypeDesc, ProductProviderCode,Amount,TermYears, TermMonths, TransactionDate, AdminMethod, SubsequentPurchase, CodeCommissionShapeID, ProposalDate, 
                      Frequency, CommRenewalFrequency, FIRSTNAMES, NAME, BIRTHDATE, POSTCODE, ProductCode, CONT_NUM, 
                      PolicyRef, WrittenTranID) 
SELECT  pt.ID, pt.PolicyID, pt.TransactionNumber, pt.TransType, pt.CommissionTypeDesc, pt.ProductProviderCode, pt.Amount, 
                      pt.TermYears, pt.TermMonths, pt.TransactionDate, pt.AdminMethod, pt.SubsequentPurchase, pt.CodeCommissionShapeID, pt.ProposalDate, 
                      pt.Frequency, pt.CommRenewalFrequency, c.FIRSTNAMES, c.NAME, c.BIRTHDATE, c.POSTCODE, pol.ProductCode, pol.CONT_NUM, 
                      pol.PolicyRef, pt.writtentranid
FROM         dbo.mstt_PolicyTransactions pt LEFT OUTER JOIN
                      dbo.msit_S_POLMAI pol ON pt.PolicyID = pol.POL_NUM LEFT OUTER JOIN
                      dbo.mstt_Clients c ON pol.CLIENT_NUM = c.CLIENT_NUM
WHERE     (pt.ProductProviderCode LIKE 'Zurich New' OR
--                      pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null))  and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and (select count(policyid) from mstt_PolicyTransactions)=1))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
--                        pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null and (select count(policyid) from mstt_PolicyTransactions where pt.policyid = pt.policyid)=1 )) -- and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and (select count(policyid) from mstt_PolicyTransactions)=1))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
                      --  pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null))  and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
                      --  pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null) or (pt.id <> '' and pt.transtypedesc <>'proposal'))  and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
                            pt.ProductProviderCode LIKE 'Zurich Leg') AND (pol.ProductCode <> 'TALA') AND (pt.TransType IN (1, 17, 23, 39)) and (pt.transtypedesc <>'proposal'or(pt.transtypedesc like 'proposal' and pt.id <> '' and pt.issuedtranid is null)or  pt.writtentranid <> pt.id) --and  (pt.ID = pt.issuedTranID or (pt.id <> '' and pt.issuedtranid is null) or (pt.id <> '' and pt.transtypedesc <>'proposal'))  and (pt.id <> pt.writtentranid or (pt.id = pt.writtentranid and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))      ----(pt.transtypedesc <>'proposal' or (pt.transtypedesc like 'proposal' and pt.issueddate is null and pt.commissionmonth is null and pt.issuedtranid is null))
                                  -- and pt.ID = pt.issuedTranID or (pt.id <> null and pt.issuedtransid is null))
                    --AND (pt.IssuedTranID IS NULL OR
                     -- pt.IssuedTranID NOT IN
                       --   (SELECT DISTINCT transactionid
                         --   FROM          mstt_Expectation)) AND (pt.TransType IN (1, 17, 23, 39))
ORDER BY pt.PolicyID, pt.TransactionNumber
*/
GO
/****** Object:  StoredProcedure [dbo].[CDCTableSizeReport]    Script Date: 7/3/2026 3:44:25 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[CDCTableSizeReport]
AS
BEGIN
	SET NOCOUNT ON;

	SELECT	 ServerName
			,DatabaseName
			,TableName
			,ReservedSpaceMB
	FROM	dbo.CDCTableSize
	ORDER BY ServerName
			,DatabaseName
			,TableName
			,ReservedSpaceMB
			;
END
GO
