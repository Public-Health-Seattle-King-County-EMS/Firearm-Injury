*****************************************************************************************************;
/*
This is example code that the EMS Division in Public Health - Seattle & King County uses to identify
EMS incidents of firearms injuries. 

Last updated: 6/22/2023

For any questions, please contact:
	Jennifer Liu (jliu@kingcounty.gov)
	Megin Parayil (mparayil@kingcounty.gov)
	Amy Poel (apoel@kingcounty.gov)
*/
******************************************************************************************************;


*Import data via ODBC;
proc sql; create table apha.inj
		as select  AgeInYears_CV,
AgeInYearsFromNarrative_CV,
AgencyName_Current_CV,
AllMedicationsAdministered_CV,
CADMasterIncidentNumber,
CanonicalNarrative_ClinicalImpre,
CanonicalNarrative_Injuries_Inj0,
CanonicalNarrative_Injuries_Inj1,
CanonicalNarrative_Injuries_Inj2,
CanonicalNarrative_PrimaryImpres,
CanonicalNarrative_SecondaryImpr,
CanonicalOutcomes_Gender,
CanonicalOutcomes_Race,
CanonicalCAD_RunNumber,
CanonicalTraumaCriteriaCDC2011_I,
CanonicalTraumaCriteriaCDC2011_M,
datepart(eTimes_02_DispatchNotifiedDateTi) as inciddt format=mmddyy10.,
eCustomResults_01_esoTraumaCrit1,
eCustomResults_01_esoTraumaCrit2,
eCustomResults_01_esoTraumaCrit3,
eCustomResults_01_esoTraumaCrit4,
eCustomResults_01_esoTraumaCrite,
eDispatch_03_EMDCardNumber,
eDispatch_04_DispatchCenterNameO,
eDisposition_12_Text_IncidentPtD,
eDisposition_27_Text_UnitDisposi,
eDisposition_28_Text_PatientEval,
eDisposition_29_Text_CrewDisposi,
eDisposition_30_Text_TransportDi,
eDisposition_31_Text_0M_ReasonFo,
eNarrative_01_Text_PatientCareRe,
ePatient_13_Text_Gender,
ePatient_14_Text_1M_Race,
ePatient_15_Text_Age,
ePatient_16_Text_AgeUnits,
ePatient_17_DOB,
eResponse_01_EMSAgencyNumber,
eResponse_03_IncidentNumber,
eResponse_14_EMSUnitCallSign,
eSituation_04_CV_PatientChiefCom, 
eSituation_09_Text_PrimarySympto,
eSituation_10_Text_1M_OtherAssoc,
eSituation_11_Text_ProvidersPrim,
eSituation_12_Text_1M_ProvidersS,
eTimes_02_DispatchNotifiedDateTi,
eVitals_06_FirstPresentSystolic_,
eVitals_14_RespiratoryRate_First,
eVitals_23_GCSTotal_FirstPresent,
eVitals_33_HighestRevisedTraumaS,
eVitals_33_RevisedTraumaScore_Fi,
eVitals_33_RevisedTraumaScore_La,
Flag_Death_CV,
Flag_PseudoResponse_CV,
IncidentDate_CV,
IncidentYear_CV,
MechanismOfInjuryCategoryCode_CV,
MechanismOfInjuryCategoryLabel_C,
PrimaryResponseType_CV,
PrimarySymptomCategory_CV,
RecordSource,
RespondingAgency_PCRNumber,
SecondaryResponseType_CV,
TotalNumberOfMedicationsAdminis0,
TotalNumberOfMedicationsAdminist,
TransportCategory_Text_Standardi,
TransportDestination_Text_Standa,
TransportLevel_Text_CV,
UnitType_CV_Text,
YearQuarter_CV,
HRA_CV,
CombinedLatitudeFromCADandESO_CV,
CombinedLongitudeFromCADandESO_C,
IncidentCensusTract_CV,
RespondingInFireDistrictCode_CV,
IncidentDisposition_CV
			from NEMSIS.View_summary
			where (IncidentYear_CV >= 2019);
quit; 

*Drop CAD records, canceled/stand by records, King County EMS and Sno Co 26 records, and pseudo response records;
data apha.inj;
set apha.inj;
if RecordSource = 'CAD' then delete;
if index(upcase(eDisposition_12_Text_IncidentPtD), 'CANCELED') or index(upcase(eDisposition_12_Text_IncidentPtD), 'STANDBY') then delete; *NEMSIS 3.4 dispositions;
/*if index(upcase(eDisposition_27_Text_UnitDisposi), 'CANCELLED') or index(upcase(eDisposition_27_Text_UnitDisposi), 'NON-PATIENT') or 
	index(upcase(eDisposition_27_Text_UnitDisposi), 'NO PATIENT FOUND') then delete; *NEMSIS 3.5 dispositions;*/
if AgencyName_Current_CV in ('King County EMS', 'Sno Co FD#26') then delete;
if Flag_PseudoResponse_CV = 1 then delete;
run;

*Create CADMasterIncidentNumbers if they're missing;
data apha.inj;
set apha.inj; 
if CADMasterIncidentNumber= ' ' then CADMasterIncidentNumber=CanonicalCAD_RunNumber;
length unique_call $43.;
unique_call= TRIM(eResponse_01_EMSAgencyNumber)||eResponse_03_IncidentNumber;
run;

data apha.inj;
set apha.inj;
if CADMasterIncidentNumber= ' ' then CADMasterIncidentNumber=unique_call;
run;

*Count unique Incidents;
proc sort data=apha.inj;
by CADMasterIncidentNumber UnitType_CV_Text;
run;

data apha.inj;
set apha.inj;
by CADMasterIncidentNumber UnitType_CV_Text;	
retain N(0);
if first.CADMasterIncidentNumber then N=1;
else N=N+1;
run;

*Create incident year and dob variables;
data apha.inj;
set apha.inj;
incid_year= year(datepart(eTimes_02_DispatchNotifiedDateTi));
ePatient_17_DOB=datepart(ePatient_17_DOB);
format ePatient_17_DOB mmddyy10.;
run;

*Calculate age and create age categories;
data apha.inj;
set apha.inj;
if AgeInYears_CV ~= . then age_calc = AgeInYears_CV;
if AgeInYears_CV = . then age_calc = AgeInYearsFromNarrative_CV;
run;

proc means data=apha.inj;
var age_calc;
run;

data apha.inj;
set apha.inj;
if age_calc=502 then age_calc=52;
run;

data apha.inj;
set apha.inj;
length agecat $8.;
if  0 <=age_calc<=1 then agecat="0-1";
if  2 <=age_calc<=13 then agecat="2-13";;
if  14 <=age_calc<=17 then agecat="14-17";
if  18 <=age_calc<=29 then agecat="18-29";
if  30 <=age_calc<=39 then agecat="30-39" ;
if  40 <=age_calc<=49 then agecat="40-49";
if  50 <=age_calc<=59 then agecat="50-59" ;
if  60 <=age_calc<=69 then agecat="60-69";
if  70 <=age_calc<=79 then agecat="70-79";
if  80 <=age_calc<=89 then agecat="80-89";
if  age_calc>=90 then agecat="90+";
run;

proc freq data=apha.inj;
tables agecat/missing;
run;

*Capping out the age at 115 b/c a lot of ems providers put fake years for dob, and thus inflating the age;
data apha.inj;
set apha.inj;
length agecats_apde $8.;
if  0 <=age_calc < 18 then agecats_apde="0-17";
else if  18<= age_calc < 25 then agecats_apde="18-24";
else if  25<= age_calc < 45 then agecats_apde="25-44";
else if  45<= age_calc < 65 then agecats_apde="45-64";
else if  65<= age_calc < 75 then agecats_apde="65-74";
else if  115 >= age_calc >= 75 then agecats_apde="75+";
else agecats_apde = 'Missing';
run;

proc freq data=apha.inj;
tables agecats_apde/missing;
run;

*Categorizing sex;
data apha.inj;
set apha.inj;
length gender_sv $40.;
gender_sv=ePatient_13_Text_Gender;
run;

data apha.inj;
set apha.inj;
if ((gender_sv='Not Recorded' OR gender_sv='Unknown (Unable to Determine)') AND CanonicalOutcomes_Gender ne ' ')  then gender_sv=CanonicalOutcomes_Gender;
run;

data apha.inj;
set apha.inj;
if gender_sv='male' then gender_sv='Male';
if gender_sv='M' then gender_sv='Male';
if gender_sv='female' then gender_sv='Female';
if gender_sv='Female' then gender_sv='Female';
if gender_sv='unknown' then gender_sv='Not Recorded';
run;

*Creating various flags on the record level;
*************************************
*Firearm injury flag
*************************************;
data apha.inj;
set apha.inj;
Flag_GSW=0;
if index(upcase(eSituation_04_CV_PatientChiefCom),'GUN')>0 then Flag_GSW=1;
if index(upcase(eSituation_04_CV_PatientChiefCom),'GUNSHOT')>0 then Flag_GSW=1;
if index(upcase(eSituation_04_CV_PatientChiefCom),'FIREARM')>0 then Flag_GSW=1;
if index(upcase(eSituation_04_CV_PatientChiefCom),'GSW')>0 then Flag_GSW=1;
if index(upcase(eSituation_04_CV_PatientChiefCom),'PISTOL')>0 then Flag_GSW=1;
if index(upcase(eNarrative_01_Text_PatientCareRe),'GSW')>0 then Flag_GSW=1;
if index(upcase(eNarrative_01_Text_PatientCareRe),'GUNSHOT')>0 then Flag_GSW=1;
if index(upcase(eNarrative_01_Text_PatientCareRe),'GUN SHOT')>0 then Flag_GSW=1;
if index(upcase(eNarrative_01_Text_PatientCareRe),'FIREARM')>0 then Flag_GSW=1;
if index(upcase(eNarrative_01_Text_PatientCareRe),'RIFLE')>0 then Flag_GSW=1;
if index(upcase(eNarrative_01_Text_PatientCareRe),'BULLET')>0 then Flag_GSW=1;
if index(upcase(eNarrative_01_Text_PatientCareRe),'FIRE ARM')>0 then Flag_GSW=1;
if MechanismOfInjuryCategoryLabel_C in('MV - MOTOR VEHICLE','PV - PEDESTRIAN VS. VEHICLE','MC - MOTORCYCLE') then Flag_GSW=0;
if index(upcase(eNarrative_01_Text_PatientCareRe),'NO GSW')>0 then Flag_GSW=0;
if index(upcase(eNarrative_01_Text_PatientCareRe),'HX OF GSW')>0 then Flag_GSW=0;
if index(upcase(eNarrative_01_Text_PatientCareRe),'HX OF MULTIPLE GSW')>0 then Flag_GSW=0;
if index(upcase(eNarrative_01_Text_PatientCareRe),'PREVIOUS GSW')>0 then Flag_GSW=0;
if MechanismOfInjuryCategoryLabel_C='GS - FIREARMS' then Flag_GSW=1;
if index(upcase(CanonicalNarrative_Injuries_Inj0),'FIREARM')>0 then Flag_GSW=1;
if index(upcase(CanonicalNarrative_Injuries_Inj0),'HANDGUN')>0 then Flag_GSW=1;
if index(upcase(CanonicalNarrative_Injuries_Inj2),'FIREARM')>0 then Flag_GSW=1;
if CanonicalNarrative_Injuries_Inj0='Struck by other objects ' AND  index(upcase(eSituation_04_CV_PatientChiefCom),'GUN')=0 then Flag_GSW=0;
*added 5/11/2021 - drops out other types of injuries ~n=8;
if CanonicalNarrative_Injuries_Inj0='Assault with blunt object' then Flag_GSW=0; *added 5/11/2021 - drops out pistol whipping ~n=23;
if index(upcase(eExam_05_Text_0M_HeadAssessment), "GUNSHOT WOUND")>0|index(upcase(eExam_06_Text_0M_FaceAssessment), "GUNSHOT WOUND")>0|
index(upcase(eExam_07_Text_0M_NeckAssessment), "GUNSHOT WOUND")>0|index(upcase(eExam_08_Text_0M_ChestLungsAsses), "GUNSHOT WOUND")>0|
index(upcase(eExam_11_Text_0M_AbdominalAssess), "GUNSHOT WOUND")>0|index(upcase(eExam_12_Text_0M_PelvisGenitouri), "GUNSHOT WOUND")>0| 
index(upcase(eExam_14_Text_0M_BackAndSpineAss), "GUNSHOT WOUND")>0|index(upcase(eExam_16_Text_0M_ExtremityAssess), "GUNSHOT WOUND")>0 
then Flag_GSW_new=1;
run;

*Intent flag;
data apha.inj;
set apha.inj;
length Flag_IntentFirearms $30.;
Flag_IntentFirearms=" ";
if CanonicalNarrative_Injuries_Inj0 in('Assault with firearm','Attempted Suicide','Attempted homicide','Attempted homicide','Firearm Injury (Assault)',
	'Firearm Injury (Self Inflicted)','Intentional self-harm by firearm discharge') 
	then Flag_IntentFirearms='Intentional';
if CanonicalNarrative_Injuries_Inj2 in('Intentional Self Harm') then Flag_IntentFirearms='Intentional';
if CanonicalNarrative_Injuries_Inj0 in('Firearm Injury (Accidental)','Handgun discharge and malfunction (accidental)') 
	then Flag_IntentFirearms='Unintentional';
if CanonicalNarrative_Injuries_Inj0 in('Discharge of handgun (Undetermined Intent)','Discharge of larger firearm (Undetermined Intent)') 
	then Flag_IntentFirearms='Undetermined Intent';
if eSituation_11_Text_ProvidersPrim in('Suicidal ideations','Suicide attempt')
	then Flag_IntentFirearms ='Intentional';
if eSituation_12_Text_1M_ProvidersS in('Suicidal ideations','Suicide attempt')
	then Flag_IntentFirearms ='Intentional';
if index(upcase(CanonicalNarrative_Injuries_Inj0),'ASSAULT')>0 
	then Flag_IntentFirearms='Intentional';
if index(upcase(CanonicalNarrative_Injuries_Inj0),'UNDETERMINED INTENT')>0 
	then Flag_IntentFirearms='Undetermined Intent';
if index(upcase(CanonicalNarrative_Injuries_Inj0),'ASSAULT')>0 
	then Flag_IntentFirearms='Intentional';
run;

*DOA flag;
data apha.inj;
set apha.inj;
Flag_DOA=0;
	if index(upcase(eSituation_11_Text_ProvidersPrim),"DEATH") >0 then Flag_DOA = 1; 
	if index(upcase(eSituation_11_Text_ProvidersPrim),"DOA") >0 then Flag_DOA = 1; 
	if index(upcase(eSituation_12_Text_1M_ProvidersS),"DEATH") >0 then Flag_DOA = 1; 
	if index(upcase(eSituation_12_Text_1M_ProvidersS),"DOA") >0 then Flag_DOA = 1; 
	if IncidentDisposition_CV in('6M2','6R1') then Flag_DOA = 1; 
	if PrimarySymptomCategory_CV='Obvious Death' then Flag_DOA = 1; 
	if Flag_Death_CV=1 then Flag_DOA = 1;
run;

*Suicide flag;
data apha.inj;
set apha.inj;
Flag_suicide_exp=0;
if index(upcase(eSituation_11_Text_ProvidersPrim),'SUICIDAL IDEATIONS')>0 then Flag_suicide_exp=1;
if index(upcase(eSituation_11_Text_ProvidersPrim),'SUICIDE ATTEMPT')>0 then Flag_suicide_exp=1;
if index(upcase(eSituation_12_Text_1M_ProvidersS),'SUICIDAL IDEATIONS')>0 then Flag_suicide_exp=1;
if index(upcase(eSituation_12_Text_1M_ProvidersS),'SUICIDE ATTEMPT')>0 then Flag_suicide_exp=1;
if index(upcase(eSituation_04_CV_PatientChiefCom),'SUICIDAL')>0 then Flag_suicide_exp=1;
if index(upcase(eSituation_04_CV_PatientChiefCom),'SUICIDE')>0 then Flag_suicide_exp=1;
if PrimarySymptomCategory_CV='Obvious Death' then do;
	if index(upcase(eNarrative_01_Text_PatientCareRe),'SUICIDE')>0 then Flag_suicide_exp=1;
	if index(upcase(eNarrative_01_Text_PatientCareRe),'SUICIDAL')>0 then Flag_suicide_exp=1;
end;
RUN;

*Creating flags on the incident-level;
proc sql;
  create table WANT as
  select CADMasterIncidentNumber, 
			sum(Flag_GSW) as Flag_GSW_sum,
			sum(Flag_DOA) as Flag_DOA_sum,
			sum(Flag_suicide_exp) as Flag_suicideexp_sum
  from  apha.inj
  group by CADMasterIncidentNumber;
quit;

data want2;
set want;
Flag_DOA_SV =0;
Flag_suicideexp_SV =0;
Flag_GSW_SV =0;
if Flag_DOA_sum >=1 then Flag_DOA_SV=1;
if Flag_suicideexp_sum >=1 then Flag_suicideexp_SV=1;
if Flag_GSW_sum >=1 then Flag_GSW_SV=1;
keep
CADMasterincidentNumber
Flag_DOA_SV
Flag_suicideexp_SV
Flag_GSW_SV
;
run;

proc sort data=want2;
by CADMasterincidentNumber;
run;

proc sort data=apha.inj;
by CADMasterIncidentNumber UnitType_CV_Text;
run;

data apha.inj;
merge apha.inj(in=o) want2(in=w);
by CADMasterIncidentNumber;
if o;
run;

data apha.inj;
set apha.inj;
if Flag_suicideexp_SV=1 and Flag_GSW_SV=1 then do;
	if Flag_IntentFirearms='Undetermined Intent' then Flag_IntentFirearms='Intentional';
	if Flag_IntentFirearms=' ' then Flag_IntentFirearms='Intentional';
end;
run;

*Simplify unit type categories;
data apha.inj;
set apha.inj;
if UnitType_CV_Text in('ALS','MSO') then UnitType_SV='ALS';
else if UnitType_CV_Text in('BLS','CHAPLAIN','CMT') then UnitType_SV='BLS';
run;

*Creating transport categories;
data apha.inj;
set apha.inj;
length TransportCategory_SV $35.;
if TransportCategory_Text_Standardi in('ALS','MSO','Helicopter') then TransportCategory_SV='ALS';
if TransportCategory_Text_Standardi in('Ambulance') then TransportCategory_SV='Ambulance';
if TransportCategory_Text_Standardi in('BLS') then TransportCategory_SV='BLS';
if TransportCategory_Text_Standardi in('POV','Taxi','Hearse/ME','CMT','Other','Cabulance','Law Enforcement','Not Recorded','Unknown','Not Applicable') then TransportCategory_SV='Other';
if TransportDestination_Text_Standa in('Patient not transported') then TransportCategory_SV='No Transport';
run;

*create deceased transport and alive-tranport variables;
data apha.inj;
set apha.inj;
length TransportCat_GSW $20.;
TransportCat_GSW=TransportCategory_SV;
if (Flag_GSW_SV=1 and Flag_DOA_SV=1) then TransportCat_GSW='DEAD_'|| TransportCategory_SV;
run;


*add category that identifies AMA/refused transport;
data apha.inj;
set apha.inj;
if eDisposition_12_Text_IncidentPtD in('Patient Treated, Released (AMA)') 
	then TransportCat_GSW='AMA_'|| TransportCategory_SV;
run;
data apha.inj;
set apha.inj;
if eDisposition_12_Text_IncidentPtD in('Patient Refused Evaluation/Care (Without Transport)') 
	then TransportCat_GSW='Refused_'|| TransportCategory_SV;
run;

*Creating injury severity;
data apha.inj;
set apha.inj;
length Injury_Severity_apde $30.;
if TransportCat_GSW in('DEAD_ALS','DEAD_Ambulance','DEAD_No Transport','DEAD_Other') then Injury_Severity_apde='FATAL';
if TransportCat_GSW in('ALS') then Injury_Severity_apde='SEVERE';
if TransportCat_GSW in('BLS','Ambulance','AMA_No Transport') then Injury_Severity_apde='MODERATE'; *we (DAT) decided that when a pt goes aginst medical advice, that injury likely was BLS-level...meaning that EMS wanted to transfer the patient, but the pt said no;
if TransportCat_GSW in('Other','Refused_No Transport') then Injury_Severity_apde='LOW';  *we (DAT) decided that if a pt refused care and weren't transported, their injury was likely not serious...per Jamie ALS crew will stay on-scene if they think the pt will decompensate quickly, in which they wouldn't need consent for transport;
if TransportCat_GSW in('No Transport') then Injury_Severity_apde='NO TRANSPORT'; 
run;

*add APDE Injury intent categories;
data apha.inj;
set apha.inj;
length Flag_APDEIntentGSW $30.;
Flag_APDEIntentGSW=" ";
if CanonicalNarrative_Injuries_Inj0 in('Assault with firearm','Attempted homicide','Firearm Injury (Assault)') 
	then Flag_APDEIntentGSW='Assault';
if index(upcase(MechanismOfInjuryCategoryLabel_C),'ASSAULT')>0 
	then Flag_APDEIntentGSW='Assault';
if index(upcase(CanonicalNarrative_Injuries_Inj0),'ASSAULT')>0 
	then Flag_APDEIntentGSW='Assault';
if CanonicalNarrative_Injuries_Inj0 in('Firearm Injury (Accidental)','Handgun discharge and malfunction (accidental)') 
	then Flag_APDEIntentGSW='Unintentional';
if CanonicalNarrative_Injuries_Inj0 in('Discharge of handgun (Undetermined Intent)','Discharge of larger firearm (Undetermined Intent)',
	'Discharge of unspecified firearms (Undetermined Intent)') 
	then Flag_APDEIntentGSW='Undetermined Intent';
if index(upcase(CanonicalNarrative_Injuries_Inj0),'UNDETERMINED INTENT')>0 
	then Flag_APDEIntentGSW='Undetermined Intent';
if CanonicalNarrative_Injuries_Inj2 in('Intentional Self Harm','Firearm Injury (Self Inflicted)','Intentional self-harm by firearm discharge') 
	then Flag_APDEIntentGSW='Self-inflicted/suicide';
if eSituation_11_Text_ProvidersPrim in('Suicidal ideations','Suicide attempt')
	then Flag_APDEIntentGSW ='Self-inflicted/suicide';
if Flag_suicideexp_SV=1
	then Flag_APDEIntentGSW ='Self-inflicted/suicide';
run;

proc freq data=apha.inj;
where Flag_GSW_SV=1;
tables Flag_APDEIntentGSW/missing;
run;

*Summarize intent variable by CMIN;
data have;
set apha.inj;
keep 
CADMasterIncidentNumber
Flag_APDEIntentGSW
;
run;

proc sort data=have;
by CADMasterIncidentNumber;
run;

data intent;
      set have (in=up) have;
 by CADMasterIncidentNumber;
      length intentap_con  $75.;
      retain intentap_con;
      if first.CADMasterIncidentNumber then call missing (intentap_con);
      if up then do;
              intentap_con=cats(intentap_con,Flag_APDEIntentGSW);
              end;
      else output;
run;

proc sort data=intent;
by CADMasterIncidentNumber descending intentap_con;
run;

data dd_intent;
set intent;
by CADMasterIncidentNumber;
if (first.CADMasterIncidentNumber and intentap_con ne ' ');
run;

data dd_intent;
set dd_intent;
LENGTH Flag_APDEIntentGSW_SV $25.;
	if intentap_con="Intentional" then Flag_APDEIntentGSW_SV="Intentional";
	else if index(upcase(intentap_con),'UNINTENTIONAL')>0 then Flag_APDEIntentGSW_SV="Unintentional";
	else if index(upcase(intentap_con),'ASSAULT')>0 then Flag_APDEIntentGSW_SV="Assault";
	else if index(upcase(intentap_con),'SELF-INFLICTED/SUICIDE')>0 then Flag_APDEIntentGSW_SV="Self-inflicted/suicide";
	else if index(upcase(intentap_con),'UNDETERMINED')>0 then Flag_APDEIntentGSW_SV="Undetermined Intent";
RUN;

data dd_intent;
set dd_intent;
keep
CADMasterIncidentNumber
Flag_APDEIntentGSW_SV
;
run;

proc sort data=dd_intent;
by CADMasterIncidentNumber;
run;

proc sort data=apha.inj;
by CADMasterIncidentNumber;
run;

data apha.inj;
merge apha.inj(in=o) dd_intent(in=w);
by CADMasterIncidentNumber;
if o;
run;

data apha.inj;
set apha.inj;
if Flag_APDEIntentGSW_SV=' ' then Flag_APDEIntentGSW_SV='Missing';
run;

proc freq data=apha.inj;
tables  Flag_APDEIntentGSW_SV/missing;
run;

*add month year;
data apha.inj;
set apha.inj;
monthyear = put(inciddt,monyy7.); 
run;

*Restrict to just gsw records;
data firearms.gsw_tab;
	set apha.inj;
	if Flag_GSW_SV = 1;
run;


***Update HRAs;
*Import shapefile;
proc mapimport datafile="EXAMPLE FILE PATH" out=hramap;
run;

*Convert X,Y coordinates from Washington North state plane to EPSG:4326 lat/longs;
proc gproject data=hramap from="+proj=lcc +lat_1=47.5 +lat_2=48.73333333333333 +lat_0=47 +lon_0=-120.8333333333333 +x_0=500000.0000000002 +y_0=0 +ellps=GRS80 +datum=NAD83 +to_meter=0.3048006096012192 +no_defs" 
	to="EPSG:4326" out=hramap2;
id name;
run;

*Clean EMS data's lat/long variables to match to shapefile lat/long variables;
data firearms.gsw_tab;
set firearms.gsw_tab;
y = strip(round(CombinedLatitudeFromCADandESO_CV, .000001)) + 0;
x = strip(round(CombinedLongitudeFromCADandESO_C, .000001)) + 0;
run;

*Join EMS data to shapefile to get the HRAs;
proc sort data = hramap2;
	by name;
run;

proc ginside data=firearms.gsw_tab map=hramap2 out=firearms.gsw_tab;
  id name;
run;

data firearms.gsw_tab;
	set firearms.gsw_tab;
	rename name = HRA;
run;

proc freq data = firearms.gsw_tab;
	table HRA / missing;
run;


*restrict to incident-level and KC HRAs only;
data firearms.gsw_tab;
set firearms.gsw_tab;
if N = 1 and HRA ne ''; 
keep
AgencyName_Current_CV
CADMasterincidentNumber
Flag_DOA_SV
Flag_suicideexp_SV
Flag_GSW_SV
Flag_APDEIntentGSW_SV
UnitType_SV 
IncidentYear_CV 
agecat 
gender_sv
age_calc
CanonicalNarrative_ClinicalImpre
CanonicalNarrative_Injuries_Inj0
CanonicalNarrative_Injuries_Inj1
CanonicalNarrative_Injuries_Inj2
CanonicalNarrative_PrimaryImpres
CanonicalNarrative_SecondaryImpr
eResponse_14_EMSUnitCallSign
eSituation_04_CV_PatientChiefCom
eSituation_09_Text_PrimarySympto
eSituation_11_Text_ProvidersPrim
eSituation_12_Text_1M_ProvidersS
eTimes_02_DispatchNotifiedDateTi
MechanismOfInjuryCategoryCode_CV
MechanismOfInjuryCategoryLabel_C
PrimaryResponseType_CV
PrimarySymptomCategory_CV
RespondingAgency_PCRNumber
TransportCategory_SV
inciddt
N
Injury_Severity_apde
agecats_apde
HRA
CombinedLatitudeFromCADandESO_CV
CombinedLongitudeFromCADandESO_C
TransportCat_GSW
eDisposition_12_Text_IncidentPtD
IncidentCensusTract_CV
RespondingInFireDistrictCode_CV
ePatient_14_Text_1M_Race
monthyear
;
run;


*Simplifying transport type;
data firearms.gsw_tab;
set firearms.gsw_tab;
length transportType_apde $20.;
if TransportCat_GSW in('ALS') then transportType_apde='ALS';
else if TransportCat_GSW in('BLS','Ambulance') then transportType_apde='BLS';
else if TransportCat_GSW in('Other') then transportType_apde='Other';
else if TransportCat_GSW in('Refused_No Transport','AMA_No Transport') then transportType_apde='Refused Transport';
else if TransportCat_GSW in('DEAD_ALS','DEAD_Ambulance','DEAD_No Transport','DEAD_Other') then transportType_apde='Dead';
else if TransportCat_GSW in('No Transport') then transportType_apde='No Transport';
run;

****Export data accordingly for dashboard****;

