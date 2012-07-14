jQuery ->
  $("form.repository_edit_form").submit ->
    $("#repository_password").val().length > 0 || confirm("You have not set a password for the repository; it must be re-entered whenever an update is made to the record. Note that repository integration is likely to fail unless the credentials are correctly set.\n\nAre you sure you wish to save this repository record without a password?")