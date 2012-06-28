#repository javascript

jQuery ->
  $("input#doc_deposit").click ->
    count = parseInt($("input#deposit-count").val());
    return (count == 0) || confirm("This plan has already been deposited.\nAre you sure you wish to deposit it again? ");
