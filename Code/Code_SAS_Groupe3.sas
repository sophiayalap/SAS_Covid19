***Reset du journal et de l'output;
dm 'log;clear;output;clear;';

ODS pdf file='C:\Users\rmani\Desktop\SAS\SAS projet\Sortie1.pdf';

***Création d'une librairie in;
libname in "C:\Users\rmani\Desktop\SAS\SAS projet";
run;

***Importation de la table csv sous SAS;

/*PROC IMPORT datafile="C:\Users\saber\Desktop\Cours\M2 TIDE\Application SAS\Projet\owid-covid-data_16112021.csv"
	out=in.covid
	dbms=csv replace;
	delimiter=",";	
	guessingrows=MAX;	
	getnames=yes;
RUN;*/


***Copie de la table dans une librairie temporaire;
DATA dataset; set in.covid;
RUN;

/*********************
Objectif: Obtenir le nombre de variables et d'observations dans une table proprement
1)Extraire les informations avec une proc contents et l'ods output
2)Enregistrer dans un fichier jpg la table
*********************/
***trace on permet d'avoir le nom des tables en sortie, l'ods output permet d'enregistrer une table;
ODS trace on;
ODS output Attributes=exploration (keep=Label2 cValue2);
PROC CONTENTS data=dataset; RUN;
ODS trace off;

DATA exploration(rename=(Label2=objets cValue2=nombre)); set exploration; 
	if Label2 ^='Observations' and Label2 ^='Variables' then delete;
RUN;

***Permet d'enregistrer la sortie dans un fichier jpg;
***ODS jpeg file='C:\Users\saber\Desktop\Cours\M2 TIDE\Application SAS\Projet\Sortie SAS\N_obs_var.jpg';
PROC PRINT data=exploration; RUN;
***ODS jpeg close;

proc contents data=dataset noprint out=contents ; run;


/*********************
Objectif: Représenter sur un barplot les variables ayant plus de 50% de valeurs manquantes
1)Obtenir le nombre de valeur par variable
2)Transposer la table afin de pouvoir créer un barplot facilement
3)Calcule du pourcentage de valeurs manquantes
4)Création du barplot
*********************/

***Permet d'obtenir le nombre d'observations par variable (N);
PROC MEANS data=dataset noprint;
output out=stat(drop=_TYPE_ _FREQ_);
RUN;

***Garde seulement le nombre d'observations N;
DATA table_miss; set stat;
if _STAT_ ^= 'N' then delete; 
RUN;

***Transpose de la table afin d'appliquer une PROC SGPLOT;
PROC TRANSPOSE data=table_miss
out=table_miss;
RUN;

***Calcule les valeurs manquantes en divisant le nombre d'observations par variables (N) par le nombre d'observations total de la table;
DATA table_miss (rename=(COL1=observations _NAME_=var)); set table_miss;
attrib percent_missing length=8 format=percent8.2;
total_obs=133499;
missing_obs=total_obs-COL1;
percent_missing=missing_obs/total_obs;
RUN;

***Supprime les variables qui ont moins de 50% des valeurs manquantes pour ne pas surcharger le graphique;
DATA table_miss; set table_miss;
if percent_missing<0.5 then delete;
RUN;

***Création du barplot;
***ODS pdf file='C:\Users\saber\Desktop\Cours\M2 TIDE\Application SAS\Projet\Sortie SAS\barplot_missing_value.pdf';
Title 'Variables ayant plus de 50% de valeurs manquantes';
PROC SGPLOT data=table_miss;
vbar var/response=percent_missing;
yaxis label=' ';
xaxis valueattrs =(size=8);
RUN;
***ODS pdf close;


/*********************
 Objectif: Représenter la proportion de la population décédée du covid par continent depuis le début de l'épidémie
1)Garder seulement les continents dans une nouvelle table
2)Récupérer la population par continent
3)Récupérer le nombre total de décès par continent
4)Calculer la proportion de décès (décès totaux/population)
5)Créer le barplot représentant la proportion de décès total par continent
*********************/

***Attribue un format numérique à la variable total_deaths;
DATA dataset; set dataset;
	total_deaths_num = input(total_deaths, 20.);
RUN;

***Création d'une nouvelle table avec seulement les continents;
DATA continent; set dataset;
	if location='Africa' or location='Asia' or location='Europe' or location='North America' or location='Oceania' or location='South America';
RUN;

***Trie de la table par continent;
PROC SORT data=continent;
	by location;
RUN;

***Récupération de la population par continent (valeurs identiques pour chaque continent max/min/mean donne le même résultat);
PROC MEANS data=continent noprint;
	var population;
	by location;
	output out=population_by_continent(drop=_TYPE_ _FREQ_) max=population_by_continent;
RUN;

***Vérification de la population mondiale;
DATA population_by_continent; set population_by_continent;
	retain population_sum 0;
	population_sum=population_sum+population_by_continent;
RUN;

***Récupére la dernière valeur du nombre de décès total avec max par continent;
PROC MEANS data=continent noprint;
	var total_deaths_num;
	by location;
	output out=deaths_by_continent(drop=_TYPE_ _FREQ_) max=deaths_by_continent;
RUN;

***Fusion des tables;
DATA death_rate_by_continent; merge population_by_continent deaths_by_continent;
	by location;
RUN;

***Calcule du pourcentage de décès au sein d'un continent;
DATA death_rate_by_continent; set death_rate_by_continent;
	death_rate=deaths_by_continent/population_by_continent;
RUN;

***création du barplot représentant le nombre de mort par continent, group permet d'obtenir des couleurs différentes;
***ODS pdf file='C:\Users\saber\Desktop\Cours\M2 TIDE\Application SAS\Projet\Sortie SAS\barplot_death_rate.pdf';
PROC SGPLOT data=death_rate_by_continent;
vbar location/name='u1' response=death_rate group=location legendlabel='Régions';
xaxis label='Régions';
yaxis label='Proportion de décès due au Covid';
keylegend 'u1';
RUN;
***ODS pdf close;




/*********************
Objectif: Création d'une macro permettant de réprésenter l'évolution des nouveaux cas et des patients
en soins intensifs pour un pays donné
1)Macro prenant en entrée une table, le nom d'un pays entre guillemets, et les dates de confinement de ce pays
*********************/

%macro contamination_evolution(dataset, country_with_quote, lockdown_dates);

/*Suppression des valeurs négatives de nouveaux cas;*/
DATA pregraph; set &dataset;
	if new_cases<0 then delete;
RUN;

/*Plot de l'évolution  l'évolution des nouveaux cas et des patients
en soins intensifs pour un pays donné
-Deux courbes sont représentés sur deux axes différents avec l'option y2axis
-l'options VALUES est à modifié en fonction des pays
-Des marqueurs indiquant les dates de confinement sont ajoutées à partir des paramètres d'entrée de la macro;
title 'Evolution des contaminations et hospitalisations en soins intensifs';*/
PROC SGPLOT data = pregraph;
	where location = &country_with_quote;
	series x = date y =new_cases/name='v1' legendlabel='Contaminations';
	series x=date y=icu_patients/y2axis name='v2' legendlabel='Patients en soins intensifs';
	xaxis label='Mois';
	yaxis label='Nbr contaminations';
	y2axis label= 'Nbr hospitalisations' VALUES= (0 TO 40000 BY 5000);
	refline &lockdown_dates/axis=x label=('1er confinement' '2e confinement' '3e confinement' '4e confinement' '5e confinement' '6e confinement' ) lineattrs=(color='green');
	keylegend "v1" "v2";
RUN;

%MEND; 

/*Enregistre l'output dans un fichier pdf;
***ODS pdf file='C:\Users\saber\Desktop\Cours\M2 TIDE\Application SAS\Projet\Sortie SAS\France.pdf';*/
%contamination_evolution(dataset, 'France', "17MAR2020"d "30OCT2020"d "03APR2021"d); RUN;
***ODS pdf close;


/*********************
Objectif: Création d'une macro permettant de réprésenter l'évolution des patients hospitalisés et le nombre 
de personne vaccinés pour un pays donné
1)Macro prenant en entrée une table, le nom d'un pays entre guillemets, et les dates de confinement de ce pays
*********************/
%macro vaccination_mesure(dataset, country_with_quote, lockdown_dates);

***Plot de l'évolution  l'évolution des patients hospitalisés et du nombre de vaccinations pour un pays donné
-Deux courbes sont représentés sur deux axes différents avec l'option y2axis
-Des marqueurs indiquant les dates de confinement sont ajoutées à partir des paramètres d'entrée de la macro;
title "Evolution du nombre d'hospitalisations et de vaccinations";
proc sgplot data = &dataset;
	where location = &country_with_quote;
	series x = date y =hosp_patients/legendlabel='Patients hospitalisés';
	series x=date y=people_vaccinated/y2axis legendlabel='Vaccinations';
	xaxis label='Mois';
	yaxis label='Nbr de patients hospitalisés';
	y2axis label='Nbr de vaccinations';
	refline &lockdown_dates/axis=x label=('1er confinement' '2e confinement' '3e confinement' '4e confinement') lineattrs=(color='green');
RUN;
%MEND;

***Enregistre l'output dans un fichier pdf;
/*ODS pdf file='C:\Users\saber\Desktop\Cours\M2 TIDE\Application SAS\Projet\Sortie SAS\France_vaccination.pdf';*/
%vaccination_mesure(dataset, 'France', "17MAR2020"d "30OCT2020"d "03APR2021"d); RUN;
/*ODS pdf close;*/


/*Heatmap plot des décès*/

 /*********************
Objectif: Obtenir une heatmap du monde représentant le nombre de décès pour chaque pays
1)Préparation de la table contenant les pays du monde, élimination des données concernant les continents
2)On garde les décès totaux pour chaque pays
3)On construit une macro dans laquelle on utilise la table world de la librairie maps intégré à SAS contenant les coordonnées de chaque pays
*********************/
DATA countries; set dataset;
if location in ('Africa', 'Asia', 'Europe', 'North America', 'Oceania', 'South America') then delete;
RUN;
PROC SORT data=countries;
by location;
RUN;
PROC MEANS data=countries noprint;
	var total_deaths;
	by location;
	output out=total_deaths(drop=_TYPE_ _FREQ_) max=total_deaths;
RUN;
 
PROC SORT data=total_deaths;
by location;
RUN;

***Permet d'utiliser le format glcnsm, qui retrouve le nom d'un pays à partir d'un code propre à SAS;
goptions reset=all border;
options fmtsearch=(sashelp.mapfmts);

%heatmap_continent(Namerica, Nameric2, countries, total_deaths); RUN;

***Macro qui prend en paramètres d'entrées une table de la librairie world, une 2e table, ainsi que le nom d'une variable;
%macro heatmap_world(world, countries_table, var_mapping);

DATA &world; set maps.&world;
location=put(id,glcnsm.);
RUN;

PROC SORT data=&world;
	 by location;
RUN;

DATA &world; merge &world(IN = a) &var_mapping(IN = b);
by location;
IF a = 1 and b = 1;
RUN;

DATA &world; set &world;
	if &var_mapping=. then bucket=0;
	if 0<&var_mapping<10000 then bucket=1;
	if 10000=<&var_mapping<50000 then bucket=2;
	if 50000=<&var_mapping<100000 then bucket=3;
	if 100000=<&var_mapping then bucket=4;
RUN;

proc format;
value buckfmt
0 = 'Valeurs manquantes'
1 = 'Moins de 10 000 décès'
2 = 'entre 10 000  et 50 000 décès'
3 = 'entre 50 000 et 100 000 décès'
4 = 'Plus de 100 000 décès';
run;

legend1 
label=(position=top 'Nombre de morts totaux')  
position=(bottom center);
pattern1 value=solid color='white';
pattern2 value=solid color='light-green';  
pattern3 value=solid color='yellow';  
pattern4 value=solid color='orange'; 
pattern5 value=solid color='light-red '; 

Title 'Covid death worldwide';
PROC GMAP map=&world data=&world;
format bucket buckfmt.;
id location;
choro bucket/discrete midpoints=  0 1 2 3 4 legend=legend1;
run;
quit;

%MEND;
/*ODS pdf file='C:\Users\saber\Desktop\Cours\M2 TIDE\Application SAS\Projet\Sortie SAS\World_map.pdf';*/
%heatmap_world(world, countries, total_deaths); RUN;
/*ODS PDF close;*/

/*
////////////////////
/////GRAPH MORT/////
///////////////////
*/


data temp;set in.covid;run;/*Création table temporaire temp pour ne pas endommager celle permanente*/


/*Graphique 1*/
data temp2; set temp;
if location="India" | location="France";/*Je sélectionne les deux pays que je vais afficher dans mon graphique, pour utiliser l'option group*/
if new_deaths<0 then delete;
run;

/* Tout au long du code cette commande permet de télécharger en sortie pdf chaque résultat*/

title "Evolution des décès quotidiens en France et en Inde";
proc sgplot data = temp2;	
 styleattrs datacontrastcolors=(purple orange);/*Je spécifie les couleurs à appliquer pour mes deux séries*/
series x = date y =new_deaths / GROUP=location  ;/*Je regroupe mes deux courbes en fonction du pays sur le même graphique*/
yaxis label="Nombre de décès quotidiens" ;
xaxis label ="Date ";/* Je change les titres de mes axes x et y*/
run;



/*Report 1*/
data TEMP3; set TEMP;
if people_fully_vaccinated=. then delete;/* Je supprime les observations avec des valeurs manquantes dans la variable vaccin,pour ne pas rencontrer de problèmes dans l'étape ci-dessous*/
run;
proc sort data=temp3;by location;RUN; /* je trie ma nouvelle table pour utiliser le by dans l'étape ci-dessous*/
data temp3;set temp3;
by location;/*Je regroupe selon les pays*/
if last.location;/* Je ne garde que la dernière observation pour chaque pays, qui contient les informations nécessaires pour la proc report*/
pct_vac=(people_fully_vaccinated/population);/* Calcul pourcentage de vaccinés de la population*/
IF pct_vac>=0.5 then groupe="Majorité de la population vaccinée";
IF pct_vac<0.5 then groupe="Minorité de la population vaccinée";/*Je sépare les pays en 2 groupes selon le pourcentage de vacciné*/
run;

title "Impact de la vaccination sur le Covid-19";
proc report data= temp3
 style(header)={fontstyle=roman background=aliceblue font_weight=BOLD cellspacing=5 verticalalign=middle color=default  borderwidth=2}
;/*Formatage du style*/
where iso_code in ("NZL", "USA","FRA","TUN","IND"); /*Sélection des pays */
column  groupe  location pct_vac total_deaths total_cases  tx_lt;/*Sélection des variables nécessaires*/
define groupe/ group "Classement";
define location/group CENTER "Country";/* 2 Variables de groupe*/
define pct_vac/ order descending format=percent8. "Pourcentage de vaccinés";
define total_deaths/ analysis  "Nombre total /de décès";
define total_cases/analysis noprint;
define tx_lt/computed format=percent8.2"Taux de létalité /en pourcentage";/*Variable calculée ci-dessous*/
 compute tx_lt;
tx_lt=(_C4_/_C5_);
endcomp;
break after groupe / summarize style=Header{background=lightyellow color=black};/*Résumé des variables en somme par groupe*/
 compute after groupe;
 
    line 50*"*";
  endcomp;
endcomp;
run;



/*Report 2*/
data temp4;set temp;
  length chardate $30.;/* Acroissement de la longueur de la variable pour contenir les modalités précisées ci-dessous*/

   chardate = put(date,YYMMDD10.);/* Nouvelle variable date en caractère pour remplacer dates par des chaînes de charactères*/
   if iso_code in ("NZL", "USA","FRA","TUN","IND"); /*Sélection des pays*/
run;
data temp4;set temp4;/* Modification des dates en périodes de confinement ou non */
if location="France" and date<="16MAR2020"d then chardate='Début COVID-19';
if location="France" and "17MAR2020"d<=date<="10MAY2020"d then chardate='Premier confinement';
if location="France" and "11MAY2020"d<=date<="29OCT2020"d then chardate='Post confinement 1';
if location="France" and "30OCT2020"d<=date<="15DEC2020"d then chardate='Deuxième confinement';
if location="France" and "16DEC2020"d<=date<="02APR2021"d then chardate='Post confinement 2';
if location="France" and "03APR2021"d<=date<="03MAY2021"d then chardate='Troisième confinement';
if location="France" and date=>"04MAY2021"d then chardate='Post confinement 3';

if location="United States" and date<"01MAR2020"d then chardate='Début COVID-19';
if location="United States" and "01MAR2020"d<=date<="01MAY2020"d then chardate='Premier confinement';
if location="United States" and date=>"02MAY2020"d then chardate='Politique sans confinement';

if location="New Zealand" and date<="24MAR2020"d then chardate='Début COVID-19';
if location="New Zealand" and "25MAR2020"d<=date<="27APR2020"d  then chardate='Premier confinement';
if location="New Zealand" and "28APR2020"d<=date<="16AUG2021"d  then chardate='Post confinement 1';
if location="New Zealand" and "17AUG2020"d<=date<="02SEP2021"d  then chardate='Deuxième confinement';
if location="New Zealand" and date=>"03SEP2021"d then chardate='Post confinement 2';

if location="India" and date<="24MAR2020"d then chardate='Début COVID-19';
if location="India" and "25MAR2020"d<=date<="31MAY2020"d  then chardate='Premier confinement';
if location="India" and "01JUN2020"d<=date<="04APR2021"d  then chardate='Post confinement 1';
if location="India" and "05APR2021"d<=date<="15JUN2021"d  then chardate='Deuxième confinement';
if location="India" and date=>"16JUN2021"d then chardate='Post confinement 2';

if location="Tunisia" and date<="17MAR2020"d then chardate='Début COVID-19';
if location="Tunisia" and "18MAR2020"d<=date<="04MAY2020"d  then chardate='Premier confinement';
if location="Tunisia" and "05MAY2020"d<=date<="13JAN2021"d  then chardate='Post confinement 1';
if location="Tunisia" and "14JAN2021"d<=date<="17JAN2021"d  then chardate='Deuxième confinement';
if location="Tunisia" and "18JAN2021"d<=date<="08MAY2021"d  then chardate='Post confinement 2';
if location="Tunisia" and "09MAY2021"d<=date<="16MAY2021"d  then chardate='Troisième confinement';
if location="Tunisia" and date>="17MAY2021"d  then chardate='Post confinement 3';

run;

title "Impact d'une mesure de confinement national sur le Covid-19";
 proc report data= temp4
 style(header)={fontstyle=roman background=aliceblue font_weight=BOLD verticalalign=middle cellspacing=5    borderwidth=2}
  style(column)={color=black};/*Formatage du style*/
column location  chardate    new_deaths  population tx_mort new_cases tx_inc;/*Sélection des variables nécessaires*/
define location/group "Pays";/*2 variables de groupe*/
define chardate/ group order=data  width=52 "Chronologie des /confinements nationaux";/*affichage selon ordre de la table temp4*/
define new_deaths/analysis  sum missing "Nombre de /morts";
define new_cases/analysis sum missing"Nombre de /cas positifs";
define population/analysis MAX missing spacing=30 center "Population";
define tx_mort/missing computed "Taux mortalité /pour 100000 habitants";
define tx_inc/computed "Taux d'incidence /pour 100000 habitants";
 compute tx_mort;
tx_mort=(new_deaths.sum/population.MAX)*100000;
endcomp;
 compute tx_inc;
tx_inc=(_C6_/_C4_)*100000;
endcomp;
 break after location / summarize style=Header{background=lightyellow color=default};/*Résumé des variables en somme par groupe*/
 compute after location;
  endcomp;
run;



/*On ne retient que certaines variables*/
data covid; set in.covid;
	keep   
	total_cases
	new_cases
	new_cases_smoothed
	new_deaths
	new_deaths_smoothed
	total_deaths 
	date
	location
	continent
	population
	population_density 
	reproduction_rate
	gdp_per_capita
	life_expectancy 
	human_development_index
	people_fully_vaccinated
	handwashing_facilities
	hospital_beds_per_thousand
	cardiovasc_death_rate
	diabetes_prevalence
	stringency_index
	male_smokers
	female_smokers;
run;
/*
//////////////////
/////MAP CAS/////
////////////////
*/

/* On ne garde que les pays */
DATA countries; set covid;
if location in ('Africa', 'Asia', 'Europe', 'North America', 'Oceania', 'South America') then delete;
RUN;

/* Tri de la table par pays */
PROC SORT data=countries;
by location;
RUN;

/* Calcul du % de cas positifs par pays */
data countries;
	set countries;
	proportion = (total_cases/population)*100;
run;

/* Tableau contenant la valeur max du % de cas positifs par pays */
proc means data = countries noprint;
	var proportion;
	by location;
	output out = proportion(drop=_TYPE_ _FREQ_) max= proportion;
run;


/* Tri de la table */
PROC SORT data=proportion;
by location;
RUN;

/* Options pour utiliser la macro */
goptions reset=all border;
options fmtsearch=(sashelp.mapfmts);


/* Macro nous permettant de creer la heatmap */
%macro heatmap_world(world, countries_table, var_mapping);

DATA &world; set maps.&world;
location=put(id,glcnsm.);
RUN;

PROC SORT data=&world;
	 by location;
RUN;


/* Merge de notre table avec celle du monde */
DATA &world; merge &world(IN = a) &var_mapping(IN = b);
by location;
IF a = 1 and b = 1;
RUN;


/* Definition des seuils */
DATA &world; set &world;
	if &var_mapping=. then bucket=0;
	if 0<&var_mapping<1 then bucket=1;
	if 1<&var_mapping<2 then bucket=2;
	if 2=<&var_mapping<4 then bucket=3;
	if 4=<&var_mapping<6 then bucket=4;
	if 6=<&var_mapping<8 then bucket=5;
	if 8=<&var_mapping<10 then bucket=6;
	if 10=<&var_mapping<15 then bucket=7;
	if 15=<&var_mapping<20 then bucket=8;
	if 20=<&var_mapping then bucket=9;
RUN;


/* Label pour les seuils */
proc format;
value buckfmt
0 = 'Valeurs manquantes'
1 = 'Moins de 1 %'
2 = 'Entre 1 et 2 %'
3 = 'Entre 2 et 4 %'
4 = 'Entre 4 et 6 %'
5 = 'Entre 6 et 8 %'
6 = 'Entre 8 et 10 %'
7 = 'Entre 10 et 15 %'
8 = 'Entre 15 et 20 %'
9 = 'Plus de 20 %';
run;


/* Definition de la couleur de chaque seuil */
legend1 
label=(position=top 'Proportion de cas de COVID-19 par pays')  
position=(bottom center);
pattern1 value=solid color="white";
pattern2 value=solid color='#D4EFDF';  
pattern3 value=solid color='#FDEBD0 ';  
pattern4 value=solid color='#F9E79F'; 
pattern5 value=solid color='#F4D03F'; 
pattern6 value=solid color='#E59866'; 
pattern7 value=solid color='#d7301f'; 
pattern8 value=solid color='#D53E3E'; 
pattern9 value=solid color='#681717';
pattern10 value=solid color='black'; 



/* Map */
Title 'Cas de COVID-19 dans le monde';
PROC GMAP map=&world data=&world;
format bucket buckfmt.;
id location;
choro bucket/discrete midpoints=  0 1 2 3 4 5 6 7 8 legend=legend1;
run;
quit;

%MEND;

/* Appel de la macro pour lancer la map */
%heatmap_world(world, countries, proportion); RUN;

/*
////////////////////
/////TAB COVID/////
//////////////////
*/

/*On souhaite produire un tableau avec nbre de deces du covid par continent*/

proc means data = covid noprint ;
	class location ;
	var 	total_cases 
			total_deaths  
			people_fully_vaccinated
			population;
	output out = tab(drop=_TYPE_ _FREQ_) max= total_cases 
			total_deaths  
			people_fully_vaccinated
			population;
	run ;

data tab ; set tab ;
if location="Africa" | location="Europe" | location="North America" | 
   location="South America" | location="Asia" | location="Oceania" | location='World' then output ;
run;

/*On souhaite produire un graphique avec l'idh par continent*/

proc sort data = covid ;
	by location;
run;

data tab2; set covid;            
   by location;                
   if LAST.location;    
run;

data tab2 ; set tab2(where=(human_development_index ne .)) ;
run;

proc means data = tab2 noprint ;
	var  human_development_index 
		 handwashing_facilities 
		 hospital_beds_per_thousand 
		 / weight = population ;
	class continent ;
	output out = tab2(drop=_TYPE_ _FREQ_) 
	mean = human_development_index
		 handwashing_facilities
		 hospital_beds_per_thousand
;
run;

data tab2 ; set tab2 ;
	if continent="" then continent="World";
run;

proc sort data = tab2 ;
	by continent;
run;

data final ; 	
	merge tab(in=in1 rename=(location=continent)) tab2(in=in2)  ;
	by continent ;
	if in1=1 and in2=1;
run;

data final2
	(drop=human_development_index 
		  handwashing_facilities
		  hospital_beds_per_thousand) ; 
		set final ;
	label total_cases='Total des cas';
	label total_deaths='Total des décès';
	label people_fully_vaccinated='Personne complètement vacciner';
	label idh='Indice de dev humain';
	label hf='Installation lavage de main';
	label hb="Lit d'hopital par milliers";

		idh  = round(human_development_index,0.01);
		hf  = round(handwashing_facilities,0.01);
		hb  = round(hospital_beds_per_thousand,0.01);
run;

title "Nos variables en fonction des continents";

proc print data = final2  noobs label ;
run;

title" ";


/*
////////////////////
////TOP3 MORTS/////
//////////////////
*/

/* Premier tableau pour avoir le max de morts de chaque pays */
proc means data = covid max nonobs noprint;
	var total_deaths;
	class continent location;
	where human_development_index ne .; /* idh diff de val manquante on garde */
	output out = data2(drop=_FREQ_ where=(_TYPE_=3)) max= max_deaths;
run;

/* Tri par continent puis par nombre de morts */
proc sort data = data2 out = sorted;
	by continent descending max_deaths;
run;

/* Pour chaque continent on crÃ©e une table qui contient les top 3 des pays oÃ¹ il y a eu le plus de morts */
data work.africa;
	set sorted (firstobs=1 obs=3);
	where continent = "Africa";
run;

data work.asia;
	set sorted (firstobs=1 obs=3);
	where continent = "Asia";
run;

data work.europe;
	set sorted (firstobs=1 obs=3);
	where continent = "Europe";
run;

data work.north_america;
	set sorted (firstobs=1 obs=3);
	where continent = "North America";
run;

data work.oceanie;
	set sorted (firstobs=1 obs=3);
	where continent = "Oceania";
run;

data work.south_america;
	set sorted (firstobs=1 obs=3);
	where continent = "South America";
run;

/* Table qui contient le top 3 des pays ayant le plus de mort pour chaque continent */
data fusion (drop = _TYPE_);
set work.africa work.asia work.europe work.north_america work.oceanie work.south_america;
run;


/* Proc report mise en forme de la table fusion*/
title 'Top 3 des pays avec le plus de morts par continent';
proc report data = fusion nowd;
column continent location max_deaths;
define continent / group 'Continent';
define location / 'Pays';
define max_deaths / 'Nombre de morts';
break after continent / summarize;

compute after continent;
		continent = 'Sous-Total';
		LINE '';
		call define(_row_,'style','style={font_weight=bold}');
	endcomp;

	rbreak after / summarize;
	compute after;
		continent = 'Total';
		call define(_row_,'style','style={font_weight=bold}');
	endcomp;
  
run;
title '';

/*
////////////////////
////TOP3 GRAPH/////
//////////////////
*/

/* Lancer le code de chargement des donnÃ©es */

/* Deux graphiques :
	- Proportion du top 3 en nombre de morts dans chaque continent
	- Proportion du top 3 en nombre d'habitants dans chaque continent
 */ 

/* PrÃ©paration des donnÃ©es */

/* Pour chaque pays, on conserve le nombre cumulÃ© de morts depuis le dÃ©but de la pandÃ©mie
	On conserve Ã©galement le nombre d'habitants */
proc means data = covid max nonobs noprint;
	where human_development_index ne .;
	var total_deaths population;
	class continent location;
	output out = data4(drop=_FREQ_ where=(_TYPE_=3)) max= max_deaths population;
run;

/* Ajout de la variable group qui permet de distinguer les pays du top 3 des autres pays
	C'est cette variable qui va nous permettre de faire la distinction dans le graphique
*/
data data5;
	set data4;
	attrib group length = $20 format = $20.;
	if location in ("South Africa", "Tunisia", "Egypt",
					"India","Indonesia", "Iran",
					"Russia", "United Kingdom", "Italy",
					"United States", "Mexico", "Canada",
					"Australia", "Fiji", "Papua New Guinea",
					"Brazil", "Peru", "Colombia") then group = "Pays du top 3";
	else group = "Autres";
run;

/* Proportion du top 3 en nombre de morts dans chaque continent */
title "Proportion du Top 3 en nombre de morts dans chaque continent";
proc sgplot data = data5;
	/* Option group permet de distinguer par une couleur diffÃ©rente les pays du top 3 des autres */
	vbar continent / response = max_deaths stat = sum group = group;
	xaxis label = "Continent";
	yaxis label = "Nombre de morts";
	keylegend / title = "CatÃ©gorie";
run;
title " ";

/* Proportion du top 3 en nombre d'habitants dans chaque continent */
title "Proportion du Top 3 en nombre d'habitants dans chaque continent";
proc sgplot data = data5;
	vbar continent / response = population stat = sum group = group;
	xaxis label = "Continent";
	yaxis label = "Nombre d'habitants";
	keylegend / title = "CatÃ©gorie";
run;
title " ";

/*
//////////////////
////REP RATE/////
////////////////
*/


/* Evolution du taux de reproduction */
/* Realiser le chargement des donnees */


/* Ajout de la variable du seuil de reproduction du virus
	Pour un R > 1 -> seuil d'alerte
	Pour un R <= 1 -> seuil correct
*/

data seuil;
	set data;
	where reproduction_rate ne .;
	attrib seuil_reproduction length = $25 format = $25.;
	if reproduction_rate > 1 then seuil_reproduction = "seuil d'alerte";
	else if reproduction_rate <= 1 then seuil_reproduction = "seuil correct";
run;


/* Tri de la base par seuil de reproduction */
proc sort data = seuil;
	by seuil_reproduction;
run;

/* Premier graphique du taux de reproduction du virus dans le monde */
title 'Evolution du taux de reproduction du virus dans le monde';
proc sgplot data = seuil;
	where location = 'World';
	scatter x = date y =reproduction_rate / group = seuil_reproduction
	markerattrs=(symbol=Plus size=5px);
	/* refline axis = y permet d'ajouter une ligne horizontale au point d'ordonnÃ©e 1 */
	refline 1 / axis = y;
	xaxis label="Date";
	yaxis label = "Taux de reproduction";
	keylegend / title = "Seuil de reproduction du virus";
run;
title ' ';


/* Premier graphique du taux de reproduction du virus en France */
title 'Evolution du taux de reproduction du virus en France';
proc sgplot data = seuil;
	where location = 'France';
	scatter x = date y =reproduction_rate / group = seuil_reproduction
	markerattrs=(symbol=Plus size=5px);
	/* refline permet d'ajouter une ligne au point d'ordonnÃ©e 1 */
	refline 1 / axis = y;
	/* refline axis = x permet d'ajouter des lignes verticales aux points d'abcisse dÃ©finis
	qui correspondent aux des trois confinements nationaux */
	refline "17MAR2020"d "30OCT2020"d "03APR2021"d/
	axis=x label=('1er confinement' '2e confinement' '3e confinement') lineattrs=(color = '#4A9566');
	xaxis label="Date";
	yaxis label = "Taux de reproduction";
	keylegend / title = "Seuil de reproduction du virus";
run;
title ' ';

/*
//////////////////
/////MAP CAS/////
////////////////
*/

/*On ne retient que certaines variables*/
data covid; set in.covid;
	keep   
	total_cases
	new_cases
	new_cases_smoothed
	new_deaths
	new_deaths_smoothed
	total_deaths 
	date
	location
	continent
	population
	human_development_index
	people_fully_vaccinated
	hospital_beds_per_thousand;
run;

/*
///////////////////
/////MAP RESTRICT/////
//////////////////
*/

/* On ne garde que les pays */
DATA countries; set in.covid;
if location in ('Africa', 'Asia', 'Europe', 'North America', 'Oceania', 'South America') then delete;
RUN;

/* Tri de la table par pays */
PROC SORT data=countries;
by location;
RUN;

/* Tableau contenant la moyenne du stringency_index par pays */
proc means data = countries noprint;
	var stringency_index;
	by location;
	output out = stringency_index(drop=_TYPE_ _FREQ_) mean= stringency_index;
run;

/* Tri de la table */
PROC SORT data=stringency_index;
by location;
RUN;

/* Options pour utiliser la macro */
goptions reset=all border;
options fmtsearch=(sashelp.mapfmts);

/* Macro nous permettant de creer la heatmap */
%macro heatmap_world(world, countries_table, var_mapping);

DATA &world; set maps.&world;
location=put(id,glcnsm.);
RUN;

PROC SORT data=&world;
	 by location;
RUN;

/* Merge de notre table avec celle du monde */
DATA &world; merge &world(IN = a) &var_mapping(IN = b);
by location;
IF a = 1 and b = 1;
RUN;

/* Definition des seuils */
DATA &world; set &world;
	if &var_mapping=. then bucket=0;
	if 0<&var_mapping<10 then bucket=1;
	if 10=<&var_mapping<20 then bucket=2;
	if 20=<&var_mapping<30 then bucket=3;
	if 30=<&var_mapping<40 then bucket=4;
	if 40=<&var_mapping<50 then bucket=5;
	if 50=<&var_mapping<60 then bucket=6;
	if 60=<&var_mapping<70 then bucket=7;
	if 70=<&var_mapping<80 then bucket=8;
	if 80=<&var_mapping<90 then bucket=9;
	if 90=<&var_mapping then bucket=10;
RUN;

/* Label pour les seuils */
proc format;
value buckfmt
0 = 'Valeurs manquantes'
1 = 'Entre 0 et 10'
2 = 'Entre 10 et 20'
3 = 'Entre 20 et 30'
4 = 'Entre 30 et 40'
5 = 'Entre 40 et 50'
6 = 'Entre 50 et 60'
7 = 'Entre 60 et 70'
8 = 'Entre 70 et 80'
9 = 'Entre 80 et 90'
10 = 'Entre 90 et 100';
run;

/* Definition de la couleur de chaque seuil */
legend1 
label=(position=top 'Indice de rigueur COVID-19')  
position=(bottom center);
pattern1 value=solid color="white";
pattern2 value=solid color='#FFF7EC';  
pattern3 value=solid color='#fee8c8';  
pattern4 value=solid color='#fdd49e'; 
pattern5 value=solid color='#fdbb84'; 
pattern6 value=solid color='#fc8d59'; 
pattern7 value=solid color='#ef6548'; 
pattern8 value=solid color='#d7301f'; 
pattern9 value=solid color='#b30000'; 
pattern10 value=solid color='#990000'; 
pattern11 value=solid color='#7f0000'; 


/* Map */
Title 'Indice de sévérité des mesures prises contre le COVID-19 dans le monde';
PROC GMAP map=&world data=&world;
format bucket buckfmt.;
id location;
choro bucket/discrete midpoints=  0 1 2 3 4 5 6 7 8 9 10 legend=legend1;
run;
quit;

%MEND;
/* Appel de la macro pour lancer la map */
%heatmap_world(world, countries, stringency_index); RUN;

/*
/////////////////////
////TOP RESTRIC/////
////////////////////
*/

/*On essaye d'obtenir l'indice de rigueur moyen par pays*/
proc means data = in.covid(where=(stringency_index ne .)) noprint;
	class continent location ;
	var stringency_index ;
		output out = tab(drop=_FREQ_ where=(_TYPE_=3)) mean= stringency_moy;
run;

/*On determine les nombres totaux de cas et de décés par pays ainsi que
	le nombre d'habitants*/
proc means data = in.covid noprint ;
	class continent location ;
	var total_deaths total_cases population ;
		output out = tab2(drop= _FREQ_ where=(_TYPE_=3))
			max=total_deaths total_cases population;
run;

data tab(drop=_TYPE_) ; merge tab(in=in1) tab2(in=in2);
	by continent location ;
	if in1=1 and in2=1;
run;

proc sort data = tab(where=(total_deaths ne .)) ;
	by continent stringency_moy;
run;

/*On incorpore quelque indicateur et ne garde que les pays avec l'indice de 
	rigeur de plus élevé ainsi que le plus petit par continent*/
data table ; set tab ;
	cases_pop = total_cases / population ;
	death_pop = total_deaths / population ;
	lethality = total_deaths / total_cases; 
	by continent;
	if first.continent then output;
	if last.continent then output;
run;

title "TOP des pays avec les indices de rigueur les plus et moins élevé";

PROC TABULATE DATA=table F=7.2 ORDER=DATA;
	CLASS continent location;
	VAR stringency_moy cases_pop death_pop lethality;
	TABLE continent=''*location='', stringency_moy = "Indice de rigueur"*SUM=''
						(cases_pop = "Part de la pop ayant été contaminé"
						death_pop = "Part de la pop ayant décéde du covid"
						lethality = "Part de décés parmis les contaminés" )*
							(SUM=''*F=10.5 SUM=''*F=Percent10.2) ;
RUN;

/*On decide de garder 6 pays par continent au lieu de 2*/
proc sort data = tab ;
	by continent;
run;

data tabb ; set tab ; 
	by continent;
	if first.continent then delete;
	if last.continent then delete;
run;

data table2 ; set tabb ;
	cases_pop = total_cases / population ;
	death_pop = total_deaths / population ;
	lethality = total_deaths / total_cases; 
	by continent;
	if first.continent then output;
	if last.continent then output;
run;

data tabbb ; set tabb ; 
	by continent;
	if first.continent then delete;
	if last.continent then delete;
run;

data table3 ; set tabbb ;
	cases_pop = total_cases / population ;
	death_pop = total_deaths / population ;
	lethality = total_deaths / total_cases; 
	by continent;
	if first.continent then output;
	if last.continent then output;
run;
data table2 ; set table table2 table3;
	by continent stringency_moy ;run;

proc sort data=table2 nodupkey out=table2;
    by continent stringency_moy;
run;


PROC TABULATE DATA=table2 F=7.2 ORDER=DATA ;
	CLASS continent location;
	BY continent ;
	VAR stringency_moy cases_pop death_pop lethality;
	TABLE continent=''*location='', stringency_moy = "Indice de rigueur"*SUM=''
						(cases_pop = "Part de la pop ayant été contaminé"
						death_pop = "Part de la pop ayant décéde du covid"
						lethality = "Part de décés parmis les contaminés" )*
							(SUM=''*F=10.5 SUM=''*F=Percent10.2) ;
RUN;

title " ";

data temp ; set in.covid;
	cases_pop = (new_cases / population )*100;
	cases_pop_smoothed = (new_cases_smoothed / population)*100 ;
run;

data new ; set in.covid;
if location ="Papua New Guinea";
run;

/*
///////////////
////GRAPH/////
/////////////
*/

PROC SGPLOT DATA =temp
			(rename=(location=Pays) where =(Pays in ( 'Hungary' 'Poland')
					and new_cases >= 0 and
						new_cases_smoothed >= 0));

	STYLEATTRS datacontrastcolors=(GREEN STPK BILG RED VILG DEPK);

	SERIES X=date Y=stringency_index / GROUP=Pays LINEATTRS=(thickness=3) Y2AXIS;

	SERIES X=date Y=cases_pop/ GROUP=Pays ;

	SERIES X=date Y=cases_pop_smoothed / GROUP=Pays LINEATTRS=(thickness=2);

	XAXIS LABEL="Date" ;

    YAXIS LABEL="Part de la pop ayant été contaminé";

	Y2AXIS LABEL="Indice de rigueur";

RUN;


PROC SGPLOT DATA =temp
			(rename=(location=Pays) where =(Pays in ('Germany' 'Greece')
					and new_cases >= 0 and
						new_cases_smoothed >= 0));

	STYLEATTRS datacontrastcolors=(GOLD BIGB YELLOW "#85C1E9" GOLD BIGB);

	SERIES X=date Y=stringency_index / GROUP=Pays LINEATTRS=(thickness=3) Y2AXIS;

	SERIES X=date Y=cases_pop/ GROUP=Pays ;

	SERIES X=date Y=cases_pop_smoothed / GROUP=Pays LINEATTRS=(thickness=2);

	XAXIS LABEL="Date" ;

    YAXIS LABEL="Part de la pop ayant été contaminé";

	Y2AXIS LABEL="Indice de rigueur";

RUN;

ods pdf close;






