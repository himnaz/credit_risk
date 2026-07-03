USE [prod_zurich_openwork_datawarehouse]
GO
/****** Object:  StoredProcedure [AppEnhRateProduct].[GetEnterprises]    Script Date: 7/3/2026 3:22:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/***********************************************************************************************

Name:	GetEnterprises

Author:	A Groves

Date:	19/06/2019

Description:	Get enterprises for the Enhancement Rate app

Execution:		exec AppEnhancementRate.GetEnterprises

AMENDMENT HISTORY
=================
Date	Author		Description
----	------		-----------

************************************************************************************************/
CREATE PROCEDURE [AppEnhRateProduct].[GetEnterprises]
	
AS

declare	@OwlManager2Code nvarchar(10)

set @OwlManager2Code = (select cde.Code from msit_MIWarehouseCodesAndDescriptions cde
			where cde.ColumnName = 'Manager2Code' and cde.Description = 'Owl Financial')

select	Code as EnterpriseUID,
		left(ltrim(rtrim(Descn)),50) as EnterpriseName,
		left(ltrim(rtrim(Descn)),50) + ' (' + Code + ')' as EnterpriseNameAndUIDUserView,
		Code + '|' + left(ltrim(rtrim(Descn)),50) as EnterpriseNameAndUIDValue
from	mstt_Agents
where	CompetentStatus = 1		--Active
and		AgentType in (2,46,49)	--2=Franchise;46=Access Agent;49=Directly Authorised
and		Manager2Code <> @OwlManager2Code
order	by EnterpriseName




GO
/****** Object:  StoredProcedure [AppEnhRateProduct].[GetProducts]    Script Date: 7/3/2026 3:22:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/***********************************************************************************************

Name:	GetProducts

Author:	A Groves

Date:	26/06/2019

Description:	Get products for the Enhancement Rate app

Execution:		exec AppEnhancementRate.GetProducts

AMENDMENT HISTORY
=================
Date	Author		Description
----	------		-----------

************************************************************************************************/
CREATE PROCEDURE [AppEnhRateProduct].[GetProducts]
	
AS

select	Code as ProductCode
from	sa_swift_CodeProducts
order	by ProductCode








GO
/****** Object:  StoredProcedure [AppEnhRateProduct].[GetUpliftRates]    Script Date: 7/3/2026 3:22:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/***********************************************************************************************

Name:	GetUpliftRates

Author:	A Groves

Date:	11/07/2019

Description:	Get the uplift rates for the "From Product" for the Enhancement Rate app.

Execution:		exec AppEnhancementRate.GetUpliftRates 'C&G'

AMENDMENT HISTORY
=================
Date	Author		Description
----	------		-----------

************************************************************************************************/
CREATE PROCEDURE [AppEnhRateProduct].[GetUpliftRates]
	@ProductCode varchar(8)
	
AS

declare	@OwlManager2Code nvarchar(10)

set @OwlManager2Code = (select cde.Code from msit_MIWarehouseCodesAndDescriptions cde
			where cde.ColumnName = 'Manager2Code' and cde.Description = 'Owl Financial')

--UAT 796 rows productcode 'C&G'

select	ag.Code as EnterpriseUID, left(ltrim(rtrim(ag.Descn)),50) as EnterpriseName, @ProductCode as ProductCode, au.DateInForce, convert(decimal(8,2),au.UpliftRate) as UpliftRate
from	mstt_Agents ag
		left join (	select au.AgentCode, isnull(au.ProductCode,@ProductCode) as ProductCode, MAX(au.ID) as MaxID
						from	sa_swift_AgentUplifts au
								inner join mstt_Agents ag on ag.CODE = au.AgentCode
						where	ag.CompetentStatus = 1					--1=Active
						and		ag.Manager2Code <> @OwlManager2Code 	--Not Owl
						and		isnull(au.ProductCode,@ProductCode) = @ProductCode
						group by au.AgentCode, au.ProductCode
					) LatestUpliftRate on LatestUpliftRate.AgentCode = ag.Code
										and LatestUpliftRate.ProductCode = @ProductCode
		left join sa_swift_AgentUplifts au on au.ID = LatestUpliftRate.MaxID
where	ag.CompetentStatus = 1					--1=Active
and		ag.Manager2Code <> @OwlManager2Code 	--Not Owl
and		ag.AgentType in (2,46,49)				--Enterprise Agent Type
and		isnull(au.ProductCode,@ProductCode) = @ProductCode
order	by 2,1






GO
/****** Object:  StoredProcedure [AppFoundation].[GetEnterprises]    Script Date: 7/3/2026 3:22:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/***********************************************************************************************

Name:	GetEnterprises

Author:	A Groves

Date:	20/09/2019

Description:	Get enterprises for the Foundation app

Execution:		declare @Exclusions [AppFoundation].[UID]
				insert into @Exclusions
					select '2001660'
				exec AppFoundation.GetEnterprises 'Openwork', @Exclusions
				or
				exec AppFoundation.GetEnterprises 'Owl', @Exclusions

AMENDMENT HISTORY
=================
Date	Author		Description
----	------		-----------

************************************************************************************************/
CREATE PROCEDURE [AppFoundation].[GetEnterprises]
	@Brand varchar(20),
	@EnterpriseExclusions AppFoundation.UID READONLY
AS

declare	@OwlManager2Code nvarchar(10)

set @OwlManager2Code = (select cde.Code from msit_MIWarehouseCodesAndDescriptions cde
			where cde.ColumnName = 'Manager2Code' and cde.Description = 'Owl Financial')

select	b.BRAN_ParentID, max(convert(tinyint,b.BRAN_IsHeadOffice)) as MaxIsHeadOffice
into	#Branch1
from	dbo.sa_insight_Branch b
		inner join SA_INSIGHT_Distributor d on d.DIST_ID = b.BRAN_ParentID and d.DIST_DateTo is null 		
group	by b.BRAN_ParentID

--If a Head Office branch exists then take it over normal branches; but if not, then just take the normal branches
select	fullbranch.*
into	#Branch2
from	#Branch1 summbranch
		inner join dbo.sa_insight_Branch fullbranch
					on fullbranch.BRAN_ParentID = summbranch.BRAN_ParentID
					and fullbranch.BRAN_IsHeadOffice = summbranch.MaxIsHeadOffice

--Take one branch per distributor. 
select	BRAN_ParentID, max(convert(varchar(36),BRAN_ID)) as Max_ID
into	#Branch3
from	#Branch2
group	by BRAN_ParentID

select	ag.Code as EnterpriseUID,
		left(ltrim(rtrim(ag.Descn)),50) as EnterpriseName,
		left(ltrim(rtrim(ag.Descn)),50) + ' (' +ag.Code + ')' as EnterpriseNameAndUIDUserView,
		ag.Code + '|' + left(ltrim(rtrim(ag.Descn)),50) as EnterpriseNameAndUIDValue
from	mstt_Agents ag
		inner join SA_INSIGHT_Distributor d on  D.DIST_ExternalID = ag.Code and d.DIST_DateTo is null
		inner join sa_insight_CodeDescription cat on cat.Code_CodeType = 536 and cat.Code_Code = d.DIST_Category
		inner join #Branch3 TmpB on TmpB.BRAN_ParentID =  d.DIST_ID		
		inner join SA_INSIGHT_Branch b on b.BRAN_ID = TmpB.Max_ID 
		inner join SA_INSIGHT_Address a on a.ADD_ParentID = b.BRAN_ID 
		left join @EnterpriseExclusions ee on ee.UID = ag.Code
		left join SA_INSIGHT_ContactDetails c on c.CD_ParentID = b.BRAN_ID
where	ee.UID is null				--We only want enterprises NOT in the exclusion list
and		((@Brand = 'Openwork' and ag.Manager2Code <> @OwlManager2Code)
		or
		(@Brand = 'Owl' and ag.Manager2Code = @OwlManager2Code))
order	by EnterpriseName



GO
/****** Object:  StoredProcedure [AppFoundation].[GetIndividuals]    Script Date: 7/3/2026 3:22:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/***********************************************************************************************

Name:	GetIndividuals

Author:	A Groves

Date:	19/11/2019

Description:	Get brief details for all the individuals. These are used for
				dropdown list boxes.

				Note: The exclusions list is a list of individual UIDs that already
						exist in the app to ensure that they are excluded from the
						dropdown list box to avoid setting up duplicates.

Execution:		declare @Exclusions [AppFoundation].[UID]
				insert into @Exclusions
					select '4007808'
				exec AppFoundation.GetIndividuals 'Openwork', @Exclusions
					or
				exec AppFoundation.GetIndividuals 'Owl', @Exclusions

AMENDMENT HISTORY
=================
Date		Author		Description
----		------		-----------
06/01/2020	A Groves	Completely re-written to pull in home rather than business address.
13/01/2020	A Groves	Further analysis shows that Owl are set up with main addresses and
						Openwork have home addresses, code changed accordingly.
************************************************************************************************/
CREATE PROCEDURE [AppFoundation].[GetIndividuals]
	@Brand varchar(20),
	@IndividualExclusions AppFoundation.UID READONLY
AS

declare	@OwlManager2Code nvarchar(10)
set @OwlManager2Code = (select cde.Code from msit_MIWarehouseCodesAndDescriptions cde
			where cde.ColumnName = 'Manager2Code' and cde.Description = 'Owl Financial')

declare @Today datetime
set @Today = dateadd(dd,0,datediff(dd,0,getdate()))

/***********************************************************************************************************************

This is the main data extract

************************************************************************************************************************/

select	ag.Code as IndividualUID,
		left(ltrim(rtrim(ag.Descn)),50) as IndividualName,
		left(ltrim(rtrim(ag.Descn)),50) + ' (' +ag.Code + ')' as IndividualNameAndUIDUserView,
		ag.Code + '|' + left(ltrim(rtrim(ag.Descn)),50) as IndividualNameAndUIDValue
from	sa_insight_UserDetails ud
		inner join mstt_Agents ag on ag.Code = ud.USR_ExternalID
		inner join sa_insight_Staff s on s.STAF_UserID = ud.USR_ID
		inner join (select	a.ADD_ParentID, min(ADD_Type) as Min_ADD_Type, max(Add_Type) as Max_ADD_Type
					from	sa_insight_Address a 
					where	@Today between a.ADD_DateFrom and isnull(a.ADD_DateTo,'9999-12-31')
					group	by  a.ADD_ParentID) addr on addr.ADD_ParentID = s.STAF_ID
		inner join sa_insight_Address a --ADD_Type=1=Main; 2=Alternative; 3=Correspondence; 4=Home	AG 13/01/2020
							on a.ADD_ParentID = addr.ADD_ParentID
							and @Today between a.ADD_DateFrom and isnull(a.ADD_DateTo,'9999-12-31')
							and a.ADD_Type = case when @Brand = 'Openwork' then Max_ADD_Type else Min_Add_Type end
		inner join (select	up.UPS_UserID, max(case when up.UPS_JobTitle in (5,53) then up.UPS_JobTitle+1000 else up.UPS_JobTitle end) as UPS_JobTitle
			from	SA_INSIGHT_UserDetails ud 
					inner join sa_insight_UserPosition up on up.UPS_UserID = ud.USR_ID
			where	up.UPS_DateTo is null
			group	by up.UPS_UserID) up2 on up2.UPS_UserID = ud.USR_ID 
		inner join sa_insight_UserPosition up on up.UPS_UserID = up2.UPS_UserID and case when up2.UPS_JobTitle in (1005,1053) then up2.UPS_JobTitle-1000 else up2.UPS_JobTitle end = up.UPS_JobTitle and up.UPS_DateTo is null	--AG 13/01/2020
		left join @IndividualExclusions ie on ie.UID = ag.Code 
where	ie.UID is null			--We only want individuals NOT in the exclusion list
and		ag.CompetentStatus = 1	--1=Active
and		((@Brand = 'Openwork' and ag.Manager2Code <> @OwlManager2Code)
		or
		(@Brand = 'Owl' and ag.Manager2Code = @OwlManager2Code))
order	by IndividualName








GO
/****** Object:  StoredProcedure [AppFoundation].[GetSpecificEnterprise]    Script Date: 7/3/2026 3:22:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/***********************************************************************************************

Name:	GetSpecificEnterprise

Author:	A Groves

Date:	29/09/2019

Description:	Get details for a specific enterprise for the Foundation app

Execution:		exec AppFoundation.GetSpecificEnterprise '1002870'

AMENDMENT HISTORY
=================
Date	Author		Description
----	------		-----------

************************************************************************************************/
CREATE PROCEDURE [AppFoundation].[GetSpecificEnterprise]
	@EnterpriseUID varchar(20)
AS

declare	@OwlManager2Code nvarchar(10)

set @OwlManager2Code = (select cde.Code from msit_MIWarehouseCodesAndDescriptions cde
			where cde.ColumnName = 'Manager2Code' and cde.Description = 'Owl Financial')

select	b.BRAN_ParentID, max(convert(tinyint,b.BRAN_IsHeadOffice)) as MaxIsHeadOffice
into	#Branch1
from	dbo.sa_insight_Branch b
		inner join SA_INSIGHT_Distributor d on d.DIST_ID = b.BRAN_ParentID and d.DIST_DateTo is null 		
where	d.DIST_ExternalID = @EnterpriseUID
group	by b.BRAN_ParentID

--If a Head Office branch exists then take it over normal branches; but if not, then just take the normal branches
select	fullbranch.*
into	#Branch2
from	#Branch1 summbranch
		inner join dbo.sa_insight_Branch fullbranch
					on fullbranch.BRAN_ParentID = summbranch.BRAN_ParentID
					and fullbranch.BRAN_IsHeadOffice = summbranch.MaxIsHeadOffice

--Take one branch per distributor. 
select	BRAN_ParentID, max(convert(varchar(36),BRAN_ID)) as Max_ID
into	#Branch3
from	#Branch2
group	by BRAN_ParentID

select	ag.Code as EnterpriseUID,
		left(ltrim(rtrim(ag.Descn)),50) as EnterpriseName,
		case when ag.Manager2Code = @OwlManager2Code then 'Owl' else 'Openwork' end as Brand,
		cat.Code_Description as Category,
		d.DIST_DateFrom as StartDate,
		d.DIST_DateTo as EndDate,
		a.ADD_Line1 as Address1,
		a.ADD_Line2 as Address2,
		a.ADD_Line3 as Address3,
		a.ADD_Line4 as Address4,
		a.ADD_Line5 as Address5,
		a.ADD_Postcode as PostCode,
        c.CD_Telephone as Telephone,
        c.CD_Email as Email
from	mstt_Agents ag
		inner join SA_INSIGHT_Distributor d on  D.DIST_ExternalID = ag.Code and d.DIST_DateTo is null
		inner join sa_insight_CodeDescription cat on cat.Code_CodeType = 536 and cat.Code_Code = d.DIST_Category
		inner join #Branch3 TmpB on TmpB.BRAN_ParentID =  d.DIST_ID		
		inner join SA_INSIGHT_Branch b on b.BRAN_ID = TmpB.Max_ID 
		inner join SA_INSIGHT_Address a on a.ADD_ParentID = b.BRAN_ID 
		left join SA_INSIGHT_ContactDetails c on c.CD_ParentID = b.BRAN_ID
where	Code = @EnterpriseUID




GO
/****** Object:  StoredProcedure [AppFoundation].[GetSpecificIndividual]    Script Date: 7/3/2026 3:22:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/***********************************************************************************************

Name:	GetSpecificIndividual

Author:	A Groves

Date:	19/11/2019

Description:	Get details for a specific individual for the Foundation app

Execution:		exec AppFoundation.GetSpecificIndividual '4005051'

AMENDMENT HISTORY
=================
Date		Author		Description
----		------		-----------
06/01/2020	A Groves	Completely re-written to pull in home rather than business address.
13/01/2020	A Groves	Further analysis shows that Owl are set up with main addresses and
						Openwork have home addresses, code changed accordingly.
************************************************************************************************/
CREATE PROCEDURE [AppFoundation].[GetSpecificIndividual]
	@IndividualUID varchar(20)
AS

declare	@OwlManager2Code nvarchar(10)
set @OwlManager2Code = (select cde.Code from msit_MIWarehouseCodesAndDescriptions cde
			where cde.ColumnName = 'Manager2Code' and cde.Description = 'Owl Financial')

declare @Today datetime
set @Today = dateadd(dd,0,datediff(dd,0,getdate()))

select	DISTINCT
		ud.USR_ExternalID as IndividualUID,
		ud.USR_Name as IndividualName,
		case when ag.Manager2Code = @OwlManager2Code then 'Owl' else 'Openwork' end as Brand,
		up.UPS_JobTitle as Role,
		up.UPS_DateFrom as StartDate,
		up.UPS_DateTo as EndDate,
		a.ADD_Line1 as Address1,
		a.ADD_Line2 as Address2,
		a.ADD_Line3 as Address3,
		a.ADD_Line4 as Address4,
		a.ADD_Line5 as Address5,
		a.ADD_Postcode as PostCode,
        c.CD_Telephone as Telephone,
        c.CD_Email as Email
from	sa_insight_UserDetails ud		
		inner join mstt_Agents ag on ag.Code = ud.USR_ExternalID 
		inner join sa_insight_Staff s on s.STAF_UserID = ud.USR_ID
		inner join (select	a.ADD_ParentID, min(ADD_Type) as Min_ADD_Type, max(Add_Type) as Max_ADD_Type
					from	sa_insight_Address a 
					where	@Today between a.ADD_DateFrom and isnull(a.ADD_DateTo,'9999-12-31')
					group	by  a.ADD_ParentID) addr on addr.ADD_ParentID = s.STAF_ID
		inner join sa_insight_Address a --ADD_Type=1=Main; 2=Alternative; 3=Correspondence; 4=Home	AG 13/01/2020
							on a.ADD_ParentID = addr.ADD_ParentID
							and @Today between a.ADD_DateFrom and isnull(a.ADD_DateTo,'9999-12-31')
							and a.ADD_Type = case when ag.Manager2Code <> @OwlManager2Code then Max_ADD_Type else Min_Add_Type end
		inner join (select	up.UPS_UserID, max(case when up.UPS_JobTitle in (5,53) then up.UPS_JobTitle+1000 else up.UPS_JobTitle end) as UPS_JobTitle
					from	SA_INSIGHT_UserDetails ud 
							inner join sa_insight_UserPosition up on up.UPS_UserID = ud.USR_ID
					where	ud.USR_ExternalID = @IndividualUID
					and		up.UPS_DateTo is null
					group	by up.UPS_UserID) up2 on up2.UPS_UserID = ud.USR_ID 
		inner join sa_insight_UserPosition up on up.UPS_UserID = up2.UPS_UserID and case when up2.UPS_JobTitle in (1005,1053) then up2.UPS_JobTitle-1000 else up2.UPS_JobTitle end = up.UPS_JobTitle and up.UPS_DateTo is null	--AG 13/01/2020
		left join SA_INSIGHT_ContactDetails c on c.CD_ParentID = s.STAF_ID
where	ud.USR_ExternalID = @IndividualUID
GO
/****** Object:  StoredProcedure [AppUnlicencedSale].[GetOpportunityAndCases]    Script Date: 7/3/2026 3:22:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/***********************************************************************************************

Name:	GetOpportunityAndCases

Author:	A Groves

Date:	06/02/2019

Description:	Get opportunity and case data for initial population

Execution:		exec AppUnlicencedSale.GetOpportunityAndCases 'K00125801'

AMENDMENT HISTORY
=================
Date				Author		Description
----				------		-----------
16/06/2021			S.Tourlidas  Added a condition to exclude the empty cases on policies 
************************************************************************************************/
CREATE PROCEDURE [AppUnlicencedSale].[GetOpportunityAndCases]
	@OpportunityRef varchar(30)
AS


select	CASE_CaseReference as OpportunityRef,
		CASE_CreatedDate as DateOfUnlicencedSale,
		ud.USR_ExternalID as AdviserUID,
		ud.USR_Name as AdviserName,
		uhau.BQMName as QRMName,
		uhau.AQMName as SQRMName
from	sa_insight_SalesCase sc
		left join sa_insight_UserDetails ud on ud.USR_ID = sc.CASE_AdviserID
		left join mi_insight_UserHierarchyAllUsers uhau on uhau.UserUID = ud.USR_ExternalID 
where	sc.CASE_CaseReference = @OpportunityRef
and		uhau.LatestRowInd = 1


select	BPOL_BackOfficeID as CaseID,	
		convert(varchar(20),bp.BPOL_ProductType) + ' - ' + pt.PROD_ShortName as Product,
		ProdOwner.MaxATTL_AttributeValue as ProductOwner,
		case when ProdOwner.MaxATTL_AttributeValue in ('Client','Joint')
			then CaseCT.MaxATTL_AttributeValue + ' ' + CaseCFN.MaxATTL_AttributeValue + ' ' + CaseCSN.MaxATTL_AttributeValue 
			else null
		end as ClientName,
		case when ProdOwner.MaxATTL_AttributeValue in ('Client','Joint')
			then CaseCDOB.MaxATTL_AttributeValue 
			else null
		end as ClientDOB,
		case when ProdOwner.MaxATTL_AttributeValue in ('Partner','Joint')
			then CasePT.MaxATTL_AttributeValue + ' ' + CasePFN.MaxATTL_AttributeValue + ' ' + CasePSN.MaxATTL_AttributeValue 
			else null
		end as PartnerName,
		case when ProdOwner.MaxATTL_AttributeValue in ('Partner','Joint')
			then CasePDOB.MaxATTL_AttributeValue 
			else null
		end as PartnerDOB
from	dbo.sa_insight_SalesCase sc
		left join sa_insight_BasicPolicy bp on bp.BPOL_ParentID = sc.CASE_ID 
		left join sa_insight_ProductType pt on pt.PROD_Code = bp.BPOL_ProductType
--Client
		left join (select	ATTL_ParentID, MAX(ATTL_AttributeValue) as MaxATTL_AttributeValue
					from	dbo.sa_insight_Attribute AS attr 
							inner join dbo.sa_insight_AttributeLink AttrLink on AttrLink.ATTL_AttributeID = attr.ATT_ID
					where	attr.ATT_Name = 'CASE.CLIENTTITLE'
					group	by ATTL_ParentID
					) CaseCT on CaseCT.ATTL_ParentID = sc.CASE_ID 
		left join (select	ATTL_ParentID, MAX(ATTL_AttributeValue) as MaxATTL_AttributeValue
					from	dbo.sa_insight_Attribute AS attr 
							inner join dbo.sa_insight_AttributeLink AttrLink on AttrLink.ATTL_AttributeID = attr.ATT_ID
					where	attr.ATT_Name = 'CASE.CLIENTFIRSTNAME'
					group	by ATTL_ParentID
					) CaseCFN on CaseCFN.ATTL_ParentID = sc.CASE_ID 
		left join (select	ATTL_ParentID, MAX(ATTL_AttributeValue) as MaxATTL_AttributeValue
					from	dbo.sa_insight_Attribute AS attr 
							inner join dbo.sa_insight_AttributeLink AttrLink on AttrLink.ATTL_AttributeID = attr.ATT_ID
					where	attr.ATT_Name = 'CASE.CLIENTSURNAME'
					group	by ATTL_ParentID
					) CaseCSN on CaseCSN.ATTL_ParentID = sc.CASE_ID 		
		left join (select	ATTL_ParentID, MAX(ATTL_AttributeValue) as MaxATTL_AttributeValue
					from	dbo.sa_insight_Attribute AS attr 
							inner join dbo.sa_insight_AttributeLink AttrLink on AttrLink.ATTL_AttributeID = attr.ATT_ID
					where	attr.ATT_Name = 'CASE.CLIENTDOB'
					group	by ATTL_ParentID
					) CaseCDOB on CaseCDOB.ATTL_ParentID = sc.CASE_ID 				
--Partner
		left join (select	ATTL_ParentID, MAX(ATTL_AttributeValue) as MaxATTL_AttributeValue
					from	dbo.sa_insight_Attribute AS attr 
							inner join dbo.sa_insight_AttributeLink AttrLink on AttrLink.ATTL_AttributeID = attr.ATT_ID
					where	attr.ATT_Name = 'CASE.PARTNERTITLE'
					group	by ATTL_ParentID
					) CasePT on CasePT.ATTL_ParentID = sc.CASE_ID 
		left join (select	ATTL_ParentID, MAX(ATTL_AttributeValue) as MaxATTL_AttributeValue
					from	dbo.sa_insight_Attribute AS attr 
							inner join dbo.sa_insight_AttributeLink AttrLink on AttrLink.ATTL_AttributeID = attr.ATT_ID
					where	attr.ATT_Name = 'CASE.PARTNERFIRSTNAME'
					group	by ATTL_ParentID
					) CasePFN on CasePFN.ATTL_ParentID = sc.CASE_ID 
		left join (select	ATTL_ParentID, MAX(ATTL_AttributeValue) as MaxATTL_AttributeValue
					from	dbo.sa_insight_Attribute AS attr 
							inner join dbo.sa_insight_AttributeLink AttrLink on AttrLink.ATTL_AttributeID = attr.ATT_ID
					where	attr.ATT_Name = 'CASE.PARTNERSURNAME'
					group	by ATTL_ParentID
					) CasePSN on CasePSN.ATTL_ParentID = sc.CASE_ID 
		left join (select	ATTL_ParentID, MAX(ATTL_AttributeValue) as MaxATTL_AttributeValue
					from	dbo.sa_insight_Attribute AS attr 
							inner join dbo.sa_insight_AttributeLink AttrLink on AttrLink.ATTL_AttributeID = attr.ATT_ID
					where	attr.ATT_Name = 'CASE.PARTNERDOB'
					group	by ATTL_ParentID
					) CasePDOB on CasePDOB.ATTL_ParentID = sc.CASE_ID 		
		left join (select	ATTL_ParentID, MAX(ATTL_AttributeValue) as MaxATTL_AttributeValue
					from	dbo.sa_insight_Attribute AS attr 
							inner join dbo.sa_insight_AttributeLink AttrLink on AttrLink.ATTL_AttributeID = attr.ATT_ID
					where	attr.ATT_Name = 'PRODUCT.OWNER'
					group	by ATTL_ParentID
					) ProdOwner on ProdOwner.ATTL_ParentID = bp.BPOL_ID 				
where	sc.CASE_CaseReference = @OpportunityRef
  and   coalesce(BPOL_BackOfficeID, '') <> '' 




GO
/****** Object:  StoredProcedure [AppUnlicencedSale].[GetOpportunityAndCases_Backup20210615]    Script Date: 7/3/2026 3:22:59 PM ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
/***********************************************************************************************

Name:	GetOpportunityAndCases

Author:	A Groves

Date:	06/02/2019

Description:	Get opportunity and case data for initial population

Execution:		exec AppUnlicencedSale.GetOpportunityAndCases 'K00125801'

AMENDMENT HISTORY
=================
Date	Author		Description
----	------		-----------

************************************************************************************************/
CREATE PROCEDURE [AppUnlicencedSale].[GetOpportunityAndCases_Backup20210615]
	@OpportunityRef varchar(30)
AS


select	CASE_CaseReference as OpportunityRef,
		CASE_CreatedDate as DateOfUnlicencedSale,
		ud.USR_ExternalID as AdviserUID,
		ud.USR_Name as AdviserName,
		uhau.BQMName as QRMName,
		uhau.AQMName as SQRMName
from	sa_insight_SalesCase sc
		left join sa_insight_UserDetails ud on ud.USR_ID = sc.CASE_AdviserID
		left join mi_insight_UserHierarchyAllUsers uhau on uhau.UserUID = ud.USR_ExternalID 
where	sc.CASE_CaseReference = @OpportunityRef
and		uhau.LatestRowInd = 1


select	BPOL_BackOfficeID as CaseID,	
		convert(varchar(20),bp.BPOL_ProductType) + ' - ' + pt.PROD_ShortName as Product,
		ProdOwner.MaxATTL_AttributeValue as ProductOwner,
		case when ProdOwner.MaxATTL_AttributeValue in ('Client','Joint')
			then CaseCT.MaxATTL_AttributeValue + ' ' + CaseCFN.MaxATTL_AttributeValue + ' ' + CaseCSN.MaxATTL_AttributeValue 
			else null
		end as ClientName,
		case when ProdOwner.MaxATTL_AttributeValue in ('Client','Joint')
			then CaseCDOB.MaxATTL_AttributeValue 
			else null
		end as ClientDOB,
		case when ProdOwner.MaxATTL_AttributeValue in ('Partner','Joint')
			then CasePT.MaxATTL_AttributeValue + ' ' + CasePFN.MaxATTL_AttributeValue + ' ' + CasePSN.MaxATTL_AttributeValue 
			else null
		end as PartnerName,
		case when ProdOwner.MaxATTL_AttributeValue in ('Partner','Joint')
			then CasePDOB.MaxATTL_AttributeValue 
			else null
		end as PartnerDOB
from	dbo.sa_insight_SalesCase sc
		left join sa_insight_BasicPolicy bp on bp.BPOL_ParentID = sc.CASE_ID 
		left join sa_insight_ProductType pt on pt.PROD_Code = bp.BPOL_ProductType
--Client
		left join (select	ATTL_ParentID, MAX(ATTL_AttributeValue) as MaxATTL_AttributeValue
					from	dbo.sa_insight_Attribute AS attr 
							inner join dbo.sa_insight_AttributeLink AttrLink on AttrLink.ATTL_AttributeID = attr.ATT_ID
					where	attr.ATT_Name = 'CASE.CLIENTTITLE'
					group	by ATTL_ParentID
					) CaseCT on CaseCT.ATTL_ParentID = sc.CASE_ID 
		left join (select	ATTL_ParentID, MAX(ATTL_AttributeValue) as MaxATTL_AttributeValue
					from	dbo.sa_insight_Attribute AS attr 
							inner join dbo.sa_insight_AttributeLink AttrLink on AttrLink.ATTL_AttributeID = attr.ATT_ID
					where	attr.ATT_Name = 'CASE.CLIENTFIRSTNAME'
					group	by ATTL_ParentID
					) CaseCFN on CaseCFN.ATTL_ParentID = sc.CASE_ID 
		left join (select	ATTL_ParentID, MAX(ATTL_AttributeValue) as MaxATTL_AttributeValue
					from	dbo.sa_insight_Attribute AS attr 
							inner join dbo.sa_insight_AttributeLink AttrLink on AttrLink.ATTL_AttributeID = attr.ATT_ID
					where	attr.ATT_Name = 'CASE.CLIENTSURNAME'
					group	by ATTL_ParentID
					) CaseCSN on CaseCSN.ATTL_ParentID = sc.CASE_ID 		
		left join (select	ATTL_ParentID, MAX(ATTL_AttributeValue) as MaxATTL_AttributeValue
					from	dbo.sa_insight_Attribute AS attr 
							inner join dbo.sa_insight_AttributeLink AttrLink on AttrLink.ATTL_AttributeID = attr.ATT_ID
					where	attr.ATT_Name = 'CASE.CLIENTDOB'
					group	by ATTL_ParentID
					) CaseCDOB on CaseCDOB.ATTL_ParentID = sc.CASE_ID 				
--Partner
		left join (select	ATTL_ParentID, MAX(ATTL_AttributeValue) as MaxATTL_AttributeValue
					from	dbo.sa_insight_Attribute AS attr 
							inner join dbo.sa_insight_AttributeLink AttrLink on AttrLink.ATTL_AttributeID = attr.ATT_ID
					where	attr.ATT_Name = 'CASE.PARTNERTITLE'
					group	by ATTL_ParentID
					) CasePT on CasePT.ATTL_ParentID = sc.CASE_ID 
		left join (select	ATTL_ParentID, MAX(ATTL_AttributeValue) as MaxATTL_AttributeValue
					from	dbo.sa_insight_Attribute AS attr 
							inner join dbo.sa_insight_AttributeLink AttrLink on AttrLink.ATTL_AttributeID = attr.ATT_ID
					where	attr.ATT_Name = 'CASE.PARTNERFIRSTNAME'
					group	by ATTL_ParentID
					) CasePFN on CasePFN.ATTL_ParentID = sc.CASE_ID 
		left join (select	ATTL_ParentID, MAX(ATTL_AttributeValue) as MaxATTL_AttributeValue
					from	dbo.sa_insight_Attribute AS attr 
							inner join dbo.sa_insight_AttributeLink AttrLink on AttrLink.ATTL_AttributeID = attr.ATT_ID
					where	attr.ATT_Name = 'CASE.PARTNERSURNAME'
					group	by ATTL_ParentID
					) CasePSN on CasePSN.ATTL_ParentID = sc.CASE_ID 
		left join (select	ATTL_ParentID, MAX(ATTL_AttributeValue) as MaxATTL_AttributeValue
					from	dbo.sa_insight_Attribute AS attr 
							inner join dbo.sa_insight_AttributeLink AttrLink on AttrLink.ATTL_AttributeID = attr.ATT_ID
					where	attr.ATT_Name = 'CASE.PARTNERDOB'
					group	by ATTL_ParentID
					) CasePDOB on CasePDOB.ATTL_ParentID = sc.CASE_ID 		
		left join (select	ATTL_ParentID, MAX(ATTL_AttributeValue) as MaxATTL_AttributeValue
					from	dbo.sa_insight_Attribute AS attr 
							inner join dbo.sa_insight_AttributeLink AttrLink on AttrLink.ATTL_AttributeID = attr.ATT_ID
					where	attr.ATT_Name = 'PRODUCT.OWNER'
					group	by ATTL_ParentID
					) ProdOwner on ProdOwner.ATTL_ParentID = bp.BPOL_ID 				
where	sc.CASE_CaseReference = @OpportunityRef





GO
