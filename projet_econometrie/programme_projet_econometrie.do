*************************************************************************
**  PROJET D'ECONOMETRIE - L3 S1 - Année 2026-2027
**  Sujet : Déterminants du montant des emprunts contractés
**  Base  : SRCV1_menage (enquête SRCV 2015, INSEE - Eurostat)
**  Charles GIACOMOTTO et Lucas STANUCH
**
**  VERSION INTERMEDIAIRE : Introduction + Partie 1 (statistiques descriptives)
**  Les numéros de tableaux et de figures en commentaire renvoient au rapport.
*************************************************************************

clear all
set more off
set scheme s1color

** Dossier de travail (A MODIFIER) : il doit contenir le fichier base1.dta
cd "C:\Users\charles\Documents\L3\Econometrie\Projet"
capture mkdir "graphiques"

use base1, clear


*************************************************************************
** PARTIE 1 - 1. DESCRIPTION DE LA BASE DE DONNEES
*************************************************************************

describe
count
** -> 4 198 ménages et 20 variables

** Tous les ménages de la base remboursent au moins un crédit :
sum nb_credits credits
** -> nb_credits vaut au minimum 1 et credits est toujours > 0 : la base ne contient
**    que des ménages endettés


*************************************************************************
** PARTIE 1 - 2. SELECTION DE L'ECHANTILLON DE TRAVAIL
*************************************************************************

** ---------------------------------------------------------------------
** 2.a Distributions sur la base brute (4 198 ménages)
** ---------------------------------------------------------------------

** Variable expliquée : montant mensuel des crédits à rembourser (Tableau 2)
codebook credits
sum credits, d
** -> aucune valeur manquante ; min = 1 euro et max = 15 672 euros : valeurs extrêmes

** Variables explicatives continues (Tableau 2)
sum agepr, d
count if missing(agepr)
** -> 3 valeurs manquantes ; une personne de référence a 17 ans
sum totreven, d
count if missing(totreven)
** -> 501 valeurs manquantes, soit 11,9 % des ménages (> 5 %)
list totreven credits if totreven<500
** -> 3 revenus inférieurs à 500 euros (1, 150 et 300 euros) : non crédibles

** Variables qualitatives (Tableaux 3 et 4)
tab sto credit_immo, m
tab1 nb_credits motif_a nenfants cs24pr tuu10 typlog, m
** -> valeurs manquantes : cs24pr (66, soit 1,6 %) et typlog (80, soit 1,9 %)
** -> modalités à faible effectif : nb_credits >= 3, nenfants >= 4, typlog = 6 ou 7, etc.


** ---------------------------------------------------------------------
** 2.b Nettoyage de la base (Tableau 5)
** ---------------------------------------------------------------------

** Etape 1 : valeurs atypiques de la variable expliquée
** On conserve les ménages situés entre le 1er et le 99e centile des mensualités
sum credits, d
keep if inrange(credits, r(p1), r(p99))
count
** -> 81 observations supprimées, il reste 4 117 ménages

** Etape 2 : âge de la personne de référence
drop if missing(agepr)
** -> 2 observations supprimées
drop if agepr<18
** -> 1 observation supprimée (personne de référence âgée de 17 ans)

** Etape 3 : revenu mensuel du ménage
drop if totreven<500
** -> 2 observations supprimées (revenus de 150 et 300 euros)
** (le ménage déclarant 1 euro de revenu a déjà été supprimé à l'étape 1)
gen double taux_effort = credits/totreven
list totreven credits if taux_effort>1 & !missing(taux_effort)
drop if taux_effort>1 & !missing(taux_effort)
** -> 3 observations supprimées : mensualités supérieures au revenu mensuel déclaré
count if missing(totreven)
** -> 485 revenus manquants (11,8 % > 5 %) : on garde ces ménages et on crée
**    une tranche "revenu non déclaré" (voir plus bas)

** Etape 4 : variables qualitatives
drop if missing(cs24pr)
** -> 63 observations supprimées
drop if missing(typlog)
** -> 76 observations supprimées
drop if typlog==6 | typlog==7
** -> 8 observations supprimées (habitations précaires et autres types de logement)

count
** -> ECHANTILLON DE TRAVAIL : 3 962 ménages


** ---------------------------------------------------------------------
** 2.c Création et regroupement des variables
** ---------------------------------------------------------------------

** Variable expliquée en logarithme
gen double lncredits = ln(credits)

** Revenu : logarithme (ménages ayant déclaré leur revenu) et tranches
gen double lnrevenu = ln(totreven)
gen revenu_tr = .
replace revenu_tr = 1 if totreven<2000
replace revenu_tr = 2 if totreven>=2000 & totreven<3000
replace revenu_tr = 3 if totreven>=3000 & totreven<4000
replace revenu_tr = 4 if totreven>=4000 & totreven<5000
replace revenu_tr = 5 if totreven>=5000 & !missing(totreven)
replace revenu_tr = 6 if missing(totreven)

** Statut d'occupation croisé avec le crédit immobilier sur la résidence principale
** (credit_immo = 1 uniquement pour des propriétaires : voir tab sto credit_immo)
gen statut = .
replace statut = 1 if credit_immo==1
replace statut = 2 if sto==1 & credit_immo==0
replace statut = 3 if sto==2 | sto==3

** Nombre de crédits : 1 / 2 ou plus
gen plusieurs_credits = (nb_credits>=2)

** Crédit pour un bien immobilier autre que la résidence principale
gen autre_immo = motif_a

** Nombre d'enfants : 0 / 1 / 2 / 3 ou plus
gen enfants = nenfants
replace enfants = 3 if nenfants>=3

** CSP de la personne de référence en 6 groupes
gen csp = .
replace csp = 1 if cs24pr>=10 & cs24pr<=23
replace csp = 2 if cs24pr>=31 & cs24pr<=36
replace csp = 3 if cs24pr>=41 & cs24pr<=48
replace csp = 4 if cs24pr>=51 & cs24pr<=56
replace csp = 5 if cs24pr>=61 & cs24pr<=69
replace csp = 6 if cs24pr>=71 & cs24pr<=82

** Taille de l'unité urbaine en 5 groupes
gen uu = .
replace uu = 1 if tuu10==0
replace uu = 2 if tuu10>=1 & tuu10<=3
replace uu = 3 if tuu10>=4 & tuu10<=6
replace uu = 4 if tuu10==7
replace uu = 5 if tuu10==8

** Type de logement : maison / appartement
gen maison = (typlog<=2)

** Libellés des variables
label variable credits "Mensualités de remboursement des crédits (euros)"
label variable lncredits "Logarithme des mensualités de remboursement"
label variable agepr "Âge de la personne de référence"
label variable totreven "Revenu mensuel du ménage (euros)"
label variable lnrevenu "Logarithme du revenu mensuel du ménage"
label variable revenu_tr "Revenu mensuel du ménage"
label variable statut "Statut d'occupation du logement"
label variable plusieurs_credits "Nombre de crédits en cours"
label variable autre_immo "Crédit pour un autre bien immobilier"
label variable enfants "Nombre d'enfants dans le ménage"
label variable csp "CSP de la personne de référence"
label variable uu "Taille de l'unité urbaine"
label variable maison "Type de logement"

** Libellés des modalités
label define lab_rev 1 "Moins de 2 000 €" 2 "2 000 à 2 999 €" 3 "3 000 à 3 999 €" 4 "4 000 à 4 999 €" 5 "5 000 € et plus" 6 "Revenu non déclaré"
label define lab_statut 1 "Propriétaire accédant" 2 "Propriétaire non accédant" 3 "Locataire ou logé gratuitement"
label define lab_plus 0 "Un seul crédit" 1 "Deux crédits ou plus"
label define lab_ouinon 0 "Non" 1 "Oui"
label define lab_enf 0 "Aucun enfant" 1 "1 enfant" 2 "2 enfants" 3 "3 enfants ou plus"
label define lab_csp 1 "Agriculteurs, artisans, commerçants, chefs d'ent." 2 "Cadres, prof. intellectuelles sup." 3 "Professions intermédiaires" 4 "Employés" 5 "Ouvriers" 6 "Retraités et autres inactifs"
label define lab_uu 1 "Commune rurale" 2 "Moins de 20 000 hab." 3 "20 000 à 199 999 hab." 4 "200 000 hab. et plus (hors Paris)" 5 "Agglomération parisienne"
label define lab_maison 0 "Appartement" 1 "Maison"

label values revenu_tr lab_rev
label values statut lab_statut
label values plusieurs_credits lab_plus
label values autre_immo lab_ouinon
label values enfants lab_enf
label values csp lab_csp
label values uu lab_uu
label values maison lab_maison

** Vérification des regroupements
tab sto statut, m
tab nb_credits plusieurs_credits, m
tab cs24pr csp, m
tab tuu10 uu, m
tab typlog maison, m

** Sauvegarde de l'échantillon de travail (utilisé pour toute la suite du projet)
save base_travail, replace


*************************************************************************
** PARTIE 1 - 3. STATISTIQUES DESCRIPTIVES UNIVARIEES (échantillon de travail)
*************************************************************************

** ---------------------------------------------------------------------
** 3.i Variable expliquée : credits ou ln(credits) ?
** ---------------------------------------------------------------------

** Figure 1
histogram credits, start(0.5) width(100) percent fcolor("42 120 214") lcolor(white) ///
    xlabel(0(500)4000) ytitle("Pourcentage des ménages") ///
    xtitle("Mensualités de remboursement des crédits (euros)") ///
    title("Distribution des mensualités de remboursement")
graph export "graphiques/fig01_hist_credits.png", replace width(1600)

** Figure 2
histogram lncredits, start(3.5) width(0.1) percent fcolor("42 120 214") lcolor(white) ///
    ytitle("Pourcentage des ménages") ///
    xtitle("Logarithme des mensualités de remboursement") ///
    title("Distribution du logarithme des mensualités")
graph export "graphiques/fig02_hist_lncredits.png", replace width(1600)

** Tableau 6
sum credits, d
sum lncredits, d
** Part des mensualités déclarées en multiples de 50 euros (pics de l'histogramme)
count if mod(credits,50)==0
** -> 1 270 ménages sur 3 962, soit 32 %

** Tableau 6 (suite) : tests de normalité
sktest credits lncredits, noadjust
swilk credits lncredits
** -> la normalité est rejetée pour les deux variables, mais lncredits a un skewness
**    et un kurtosis beaucoup plus proches de ceux d'une loi normale (0 et 3)
**    => on modélisera ln(credits) dans la suite du projet


** ---------------------------------------------------------------------
** 3.ii Variables explicatives continues
** ---------------------------------------------------------------------

** Tableau 7
tabstat agepr totreven lnrevenu, statistics(n mean sd min p10 p25 p50 p75 p90 max skewness kurtosis) ///
    columns(statistics) format(%9.4g)
count if agepr<25
count if agepr>80

** Taux d'effort (mensualités / revenu), ménages ayant déclaré leur revenu
sum taux_effort, d

** Figure 3
histogram agepr, start(19.5) width(2) percent fcolor("42 120 214") lcolor(white) ///
    xlabel(20(10)90) ytitle("Pourcentage des ménages") ///
    xtitle("Âge de la personne de référence (années)") ///
    title("Distribution de l'âge de la personne de référence")
graph export "graphiques/fig03_hist_age.png", replace width(1600)

** Figure 4 (ménages ayant déclaré leur revenu)
histogram totreven, start(499.5) width(500) percent fcolor("42 120 214") lcolor(white) ///
    xlabel(0(5000)25000) ytitle("Pourcentage des ménages") ///
    xtitle("Revenu mensuel du ménage (euros)") ///
    title("Distribution du revenu mensuel du ménage")
graph export "graphiques/fig04_hist_revenu.png", replace width(1600)


** ---------------------------------------------------------------------
** 3.iii Variables explicatives qualitatives
** ---------------------------------------------------------------------

** Tableau 8 (effectifs et pourcentages)
tab1 revenu_tr statut plusieurs_credits autre_immo enfants csp uu maison

** Pas de graphique pour les variables binaires (plusieurs_credits, autre_immo, maison)

** Figure 5
graph bar, over(revenu_tr, label(labsize(small) angle(20))) bar(1, color("42 120 214")) ///
    blabel(bar, format(%4.1f)) ytitle("Pourcentage des ménages") ///
    title("Revenu mensuel du ménage")
graph export "graphiques/fig05_bar_revenu.png", replace width(1600)

** Figure 6
graph bar, over(statut, label(labsize(small))) bar(1, color("42 120 214")) ///
    blabel(bar, format(%4.1f)) ytitle("Pourcentage des ménages") ///
    title("Statut d'occupation du logement")
graph export "graphiques/fig06_bar_statut.png", replace width(1600)

** Figure 7
graph bar, over(enfants) bar(1, color("42 120 214")) ///
    blabel(bar, format(%4.1f)) ytitle("Pourcentage des ménages") ///
    title("Nombre d'enfants dans le ménage")
graph export "graphiques/fig07_bar_enfants.png", replace width(1600)

** Figure 8 (modalités non ordonnées : barres triées par fréquence)
graph hbar, over(csp, sort(1) descending) bar(1, color("42 120 214")) ///
    blabel(bar, format(%4.1f)) ytitle("Pourcentage des ménages") ///
    title("CSP de la personne de référence")
graph export "graphiques/fig08_bar_csp.png", replace width(1600)

** Figure 9
graph hbar, over(uu) bar(1, color("42 120 214")) ///
    blabel(bar, format(%4.1f)) ytitle("Pourcentage des ménages") ///
    title("Taille de l'unité urbaine de résidence")
graph export "graphiques/fig09_bar_uu.png", replace width(1600)


*************************************************************************
** PARTIE 1 - 4. STATISTIQUES DESCRIPTIVES BIVARIEES
*************************************************************************
** La variable expliquée retenue est lncredits. Pour les graphiques en barres,
** on représente les mensualités en euros (plus lisibles que le logarithme).

** ---------------------------------------------------------------------
** 4.a Variables explicatives continues
** ---------------------------------------------------------------------

** Age (Tableau 9 et Figure 10)
pwcorr lncredits agepr, sig obs
bysort agepr: egen moy_lncredits = mean(lncredits)
egen tag_age = tag(agepr)
twoway (scatter moy_lncredits agepr if tag_age==1, mcolor("42 120 214")) ///
    (lfit lncredits agepr, lcolor("235 104 52") lpattern(dash) lwidth(medthick)) ///
    (qfit lncredits agepr, lcolor("27 175 122") lwidth(medthick)), ///
    legend(order(1 "Moyenne par âge" 2 "Ajustement linéaire" 3 "Ajustement quadratique") rows(1)) ///
    ytitle("Logarithme des mensualités") xtitle("Âge de la personne de référence (années)") ///
    title("Logarithme moyen des mensualités selon l'âge")
graph export "graphiques/fig10_age_lncredits.png", replace width(1600)

** Revenu (Tableau 9 et Figure 11), sur les ménages ayant déclaré leur revenu
pwcorr lncredits lnrevenu, sig obs
twoway (scatter lncredits lnrevenu, msize(vsmall) mcolor("42 120 214%30")) ///
    (lfit lncredits lnrevenu, lcolor("235 104 52") lwidth(medthick)), ///
    legend(order(1 "Ménages" 2 "Ajustement linéaire") rows(1)) ///
    ytitle("Logarithme des mensualités") xtitle("Logarithme du revenu mensuel du ménage") ///
    title("Mensualités et revenu (en logarithmes)")
graph export "graphiques/fig11_revenu_lncredits.png", replace width(1600)


** ---------------------------------------------------------------------
** 4.b Variables explicatives qualitatives (Tableau 8 : mensualités moyennes et
**     médianes, et Figures 12 à 19)
** ---------------------------------------------------------------------

** Revenu en tranches
tabstat credits, by(revenu_tr) statistics(n mean p50) format(%9.0f)
graph bar (mean) credits, over(revenu_tr, label(labsize(small) angle(20))) bar(1, color("42 120 214")) ///
    blabel(bar, format(%9.0f)) ytitle("Mensualité moyenne (euros)") ///
    title("Mensualité moyenne selon le revenu du ménage")
graph export "graphiques/fig12_moy_revenu.png", replace width(1600)

** Statut d'occupation
tabstat credits, by(statut) statistics(n mean p50) format(%9.0f)
graph bar (mean) credits, over(statut, label(labsize(small))) bar(1, color("42 120 214")) ///
    blabel(bar, format(%9.0f)) ytitle("Mensualité moyenne (euros)") ///
    title("Mensualité moyenne selon le statut d'occupation")
graph export "graphiques/fig13_moy_statut.png", replace width(1600)

** Nombre de crédits
tabstat credits, by(plusieurs_credits) statistics(n mean p50) format(%9.0f)
graph bar (mean) credits, over(plusieurs_credits) bar(1, color("42 120 214")) ///
    blabel(bar, format(%9.0f)) ytitle("Mensualité moyenne (euros)") ///
    title("Mensualité moyenne selon le nombre de crédits")
graph export "graphiques/fig14_moy_nbcredits.png", replace width(1600)

** Crédit pour un autre bien immobilier
tabstat credits, by(autre_immo) statistics(n mean p50) format(%9.0f)
graph bar (mean) credits, over(autre_immo) bar(1, color("42 120 214")) ///
    blabel(bar, format(%9.0f)) ytitle("Mensualité moyenne (euros)") ///
    title("Crédit pour un autre bien immobilier")
graph export "graphiques/fig15_moy_autreimmo.png", replace width(1600)

** Type de logement
tabstat credits, by(maison) statistics(n mean p50) format(%9.0f)
tab maison statut, row nofreq
graph bar (mean) credits, over(maison) bar(1, color("42 120 214")) ///
    blabel(bar, format(%9.0f)) ytitle("Mensualité moyenne (euros)") ///
    title("Mensualité moyenne selon le type de logement")
graph export "graphiques/fig16_moy_logement.png", replace width(1600)

** Nombre d'enfants
tabstat credits, by(enfants) statistics(n mean p50) format(%9.0f)
** lien entre nombre d'enfants, âge et accession à la propriété
tabstat agepr, by(enfants) statistics(mean) format(%9.1f)
tab enfants statut, row nofreq
graph bar (mean) credits, over(enfants) bar(1, color("42 120 214")) ///
    blabel(bar, format(%9.0f)) ytitle("Mensualité moyenne (euros)") ///
    title("Mensualité moyenne selon le nombre d'enfants")
graph export "graphiques/fig17_moy_enfants.png", replace width(1600)

** CSP (barres triées par mensualité moyenne)
tabstat credits, by(csp) statistics(n mean p50) format(%9.0f)
graph hbar (mean) credits, over(csp, sort(1) descending) bar(1, color("42 120 214")) ///
    blabel(bar, format(%9.0f)) ytitle("Mensualité moyenne (euros)") ///
    title("Mensualité moyenne selon la CSP")
graph export "graphiques/fig18_moy_csp.png", replace width(1600)

** Taille de l'unité urbaine
tabstat credits, by(uu) statistics(n mean p50) format(%9.0f)
graph hbar (mean) credits, over(uu) bar(1, color("42 120 214")) ///
    blabel(bar, format(%9.0f)) ytitle("Mensualité moyenne (euros)") ///
    title("Mensualité moyenne selon la taille de l'unité urbaine")
graph export "graphiques/fig19_moy_uu.png", replace width(1600)

** Fin de la version intermédiaire
