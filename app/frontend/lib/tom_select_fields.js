// Tom Select initialization is now owned by Rails Fields Kit's Stimulus controller.
//
// Keep this no-op compatibility hook while application.js still calls setupTomSelectFields()
// during Turbo lifecycle events. New forms should use RailsFieldsKit helpers, which emit
// data-controller="rails-fields-kit--tom-select" and are initialized by Stimulus.
export function setupTomSelectFields(_root = document) {}
