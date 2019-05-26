function openNav() {
    document.getElementById("mySideNav").style.width = "250px";
    document.getElementById("mySideNav").style.left = "0px";
    document.getElementById("mscContainer").style.left = "250px";
}

function closeNav() {
    document.getElementById("mySideNav").style.left = "-250px";
    document.getElementById("mscContainer").style.left = "0";
}