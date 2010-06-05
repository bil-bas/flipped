class GuiEventsMock
  attr_reader :events

  def initialize
    @events = Array.new
  end

  def request_event(method_name, *args)
    @events.push [method_name, args]
    nil
  end
end