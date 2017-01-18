/*
   Expanding/Contracting Menus for Gold
   Author: Geoffrey Elliott
   Updated: September, 2003
*/


function closeMenus() {
for(i=0; i<NavMenus.length; i++) {
        if(document.getElementById(NavMenus[i] + "Section")){
            document.getElementById(NavMenus[i] + "Section").style.display = "none";
            document.getElementById(NavMenus[i] + "Arrow").src = "/cgi-bin/gold/images/menu_arrow_closed.gif";
        }
    }
}

function showMenu(sectionID) {
    closeMenus();
    document.getElementById(sectionID + "Section").style.display = "block";
    document.getElementById(sectionID + "Arrow").src = "/cgi-bin/gold/images/menu_arrow_expanded.gif";
}
