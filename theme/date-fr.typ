#let month-fr = (
  "Janvier",
  "Février",
  "Mars",
  "Avril",
  "Mai",
  "Juin",
  "Juillet",
  "Août",
  "Septembre",
  "Octobre",
  "Novembre",
  "Décembre"
)

/// Returns today's date using French month names.
#let date-fr() = {
  block()[
    #datetime.today().day() #month-fr.at(datetime.today().month()-1) #datetime.today().year()
  ]
}
