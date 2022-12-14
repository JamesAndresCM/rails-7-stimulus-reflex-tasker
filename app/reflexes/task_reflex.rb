# frozen_string_literal: true

class TaskReflex < ApplicationReflex
  # Add Reflex methods in this file.
  #
  # All Reflex instances include CableReady::Broadcaster and expose the following properties:
  #
  #   - connection  - the ActionCable connection
  #   - channel     - the ActionCable channel
  #   - request     - an ActionDispatch::Request proxy for the socket connection
  #   - session     - the ActionDispatch::Session store for the current visitor
  #   - flash       - the ActionDispatch::Flash::FlashHash for the current request
  #   - url         - the URL of the page that triggered the reflex
  #   - params      - parameters from the element's closest form (if any)
  #   - element     - a Hash like object that represents the HTML element that triggered the reflex
  #     - signed    - use a signed Global ID to map dataset attribute to a model eg. element.signed[:foo]
  #     - unsigned  - use an unsigned Global ID to map dataset attribute to a model  eg. element.unsigned[:foo]
  #   - cable_ready - a special cable_ready that can broadcast to the current visitor (no brackets needed)
  #   - reflex_id   - a UUIDv4 that uniquely identies each Reflex
  #
  # Example:
  #
  #   before_reflex do
  #     # throw :abort # this will prevent the Reflex from continuing
  #     # learn more about callbacks at https://docs.stimulusreflex.com/lifecycle
  #   end
  #
  #   def example(argument=true)
  #     # Your logic here...
  #     # Any declared instance variables will be made available to the Rails controller and view.
  #   end
  #
  # Learn more at: https://docs.stimulusreflex.com/reflexes#reflex-classes
  before_reflex :find_task

  def toggle 
    if element.checked
      @task.update(completed_at: Time.current, completer: current_user)
    else
      @task.update(completed_at: nil, completer: nil)
    end

    cable_ready[ListChannel]
      .remove(selector: "#task_#{@task.id}")
      .insert_adjacent_html(
        selector: "#list_#{@task.list_id} #{element.checked ? '#complete-tasks' : '#incomplete-tasks'}",
        position: 'beforeend',
        html: ApplicationController.render(@task)
      )
      .broadcast_to(@task.list)
  end

  def destroy
    @task.destroy

    cable_ready[ListChannel]
      .remove(selector: "#task_#{@task.id}")
      .broadcast_to(@task.list)

    return unless @task.list.tasks.empty?

    cable_ready[ListChannel]
      .remove_css_class(selector: "#list_#{@task.list_id} #no-tasks", name: 'd-none')
      .broadcast_to(@task.list)
  end

  def update
    @task.update(task_params)
    morph "#task_#{@task.id}", ApplicationController.render(@task)
  end

  def reorder(position)
    @task.insert_at(position)
    morph :nothing
  end

  def assign
    @task.update(assignee_id: element.value)
    morph "#task-#{@task.id}-assignee", @task.assignee_name
  end

  private

  def find_task
    @task = Task.find(element.data_id)
  end

  def task_params = params.require(:task).permit(:name)
end
