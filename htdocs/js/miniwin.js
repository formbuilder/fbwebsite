/* miniwin opener */
    function miniwin (myLink) {
        if(! window.focus) return;

        // kludges
        fileName = '';
        windowName = 'appt';
 
        // create the window
        myminiwin = window.open(fileName,windowName,"height=550,width=575,resizable,toolbar=yes,scrollbars=yes");
        myminiwin.focus();
        myLink.target = windowName;
    }
