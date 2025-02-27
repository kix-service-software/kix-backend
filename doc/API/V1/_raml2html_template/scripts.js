// --
// Copyright (C) 2006-2025 KIX Service Software GmbH, https://www.kixdesk.com
// --
// This software comes with ABSOLUTELY NO WARRANTY. For details, see
// the enclosed file LICENSE-AGPL for license information (AGPL). If you
// did not receive this file, see https://www.gnu.org/licenses/agpl.txt.
// --
$(document).ready(function() {
  // add chapters to sidebar
  $($('.chapter > h2').get().reverse()).each(function(i, chapter) {
    $('#sidebar ul.nav-stacked').prepend('<li>' + chapter.innerHTML + '</li>');
  });

  // add response codes to tabs
  $('h2.response-title > a').each(function(i, response) {
    $(this).parent().siblings('.response-nav').append('<a class="badge response-code" href="#' + $(this).parent().attr('id') + '">' + response.innerHTML + '</a>');
  });
  
  // add toggle of schema and examples
  $('.schemas.toggleable, .examples.toggleable').each(function(i, item) {
    $(this).hide();
    $(this).prev('p').append('<a class="badge toggle" href="#">' + ($(this).is(':visible') ? 'Hide' : 'Show') + '</a>');
  });
  $('.badge.toggle').click(function(e) {
    e.preventDefault();
    var $toggleElement = $(this).parents('p').next('.schemas.toggleable, .examples.toggleable');
    $toggleElement.toggle();
    $(this).html($toggleElement.is(':visible') ? 'Hide' : 'Show');
  });

  // add toggle of resource descriptions
  $('.resource-description > h4').each(function(i, item) {
    $(this).parent().hide();
    $(this).closest('.panel').prepend('<a class="description-toggle toggle" href="#" title="Show or hide description">');
    $(this).closest('.panel').children('a.description-toggle').append($(this).detach());
  });
  $('a.description-toggle').click(function(e) {
    e.preventDefault();
    var $toggleElement = $(this).parents('.panel').children('.resource-description');
    $toggleElement.toggle();
  });

  //$('.page-header pre code, .top-resource-description pre code, .modal-body pre code').each(function(i, block) {
  //  hljs.highlightBlock(block);
  //});

  $('.schemas code').each(function() {
    if ($(this).html().startsWith('{')) {
      $(this).jsonBrowse(JSON.parse($(this).html()), {collapsed: false, withQuotes: true });
    }
  });

  $('.examples code').each(function() {
    if ($(this).html().startsWith('{')) {
      $(this).jsonBrowse(JSON.parse($(this).html()), {collapsed: false, withQuotes: true });
    }
  });

  $('pre code.lang-json').each(function() {
    console.log("JSON: " + $(this).html);
    $(this).jsonBrowse(JSON.parse($(this).html()), {collapsed: false, withQuotes: true });
  });

  $('[data-toggle]').click(function() {
    var selector = $(this).data('target') + ' pre code';
    $(selector).each(function(i, block) {
      hljs.highlightBlock(block);
    });
  });

  // open modal on hashes like #_action_get
  $(window).bind('hashchange', function(e) {
    var anchor_id = document.location.hash.substr(1); //strip #
    var element = $('#' + anchor_id);

    // do we have such element + is it a modal?  --> show it
    if (element.length && element.hasClass('modal')) {
      element.modal('show');
    }
  });

  // execute hashchange on first page load
  $(window).trigger('hashchange');

  // remove url fragment on modal hide
  $('.modal').on('hidden.bs.modal', function() {
    try {
      if (history && history.replaceState) {
          history.replaceState({}, '', '#');
      }
    } catch(e) {}
  });
});
