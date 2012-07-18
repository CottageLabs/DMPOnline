#repository javascript

jQuery ->
  $("input#doc_deposit").click ->
    has_deposited_media = parseInt($("input#has_deposited_media").val());
    return (has_deposited_media == 0) || confirm("This plan/phase has already been deposited.\nAre you sure you wish to deposit it again?");
