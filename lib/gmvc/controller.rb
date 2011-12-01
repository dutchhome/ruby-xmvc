require 'gtk2'
module GMVC
  class Controller < XMVC::Controller
    attr_reader :builder
    def self.windowing_system
      GMVCApp
    end
    # By default the glade file will be the same as the class name with a .glade suffix
    def self.glade_filename
      File.join(self.glade_directory, self.name.split("::").last.downcase[0..-11] + ".glade")
    end
    def self.glade_directory
      # return @@glade_directory if @@glade_directory
      @@glade_directory ||= File.join($project_directory, 'lib/gtk2/glade')
    end
    # By default the main window name will be the same as the class name
    def self.window_name
      self.name.split("::").last.downcase
    end
    # Initialize our extra variables
    def initialize(*args)
      super
      @attached_objects = Hash.new
      self.load
    end
    # Load the associated glade file
    def load
      puts "Loading glade file: #{self.class.glade_filename}"
      @builder = Gtk::Builder::new
      @builder.add_from_file(self.class.glade_filename)
      # self.attach_to_object(self.class.window_name, self)
      
      @builder.objects.each do |obj|
        if obj.kind_of?(Gtk::Window)
          @view_names << obj.builder_name
        end
      end
      puts @view_names
    end
    
    # Replace the restrictive __connect_signals__ from Gtk::Builder
    def __connect_signals__(connector, object, signal_name, handler_name, connect_object, flags)
      handler_name = canonical_handler_name(handler_name)
      attached_object = @attached_objects[object]
      
      # Instead of having a single if/elsif statement, we want to be able to 
      # ask the connector block to attach the signal even if there is an attached
      # object or a connect_object and no handler was defined
      if attached_object and attached_object.methods.include?(handler_name)
        handler = attached_object.method(handler_name)
      end
      if !handler and connect_object
        handler = connect_object.method(handler_name)
      end
      if !handler
        handler = connector.call(handler_name, object, signal_name)
      end
      unless handler
        $stderr.puts("Undefined handler: #{handler_name}") if $DEBUG
        return
      end

      if flags.after?
        signal_connect_method = :signal_connect_after
      else
        signal_connect_method = :signal_connect
      end

      if handler.arity.zero?
        object.send(signal_connect_method, signal_name) {handler.call}
      else
        object.send(signal_connect_method, signal_name, &handler)
      end
    end
    
    # Call this prior to connecting signals to attach signals to ruby objects
    def attach_to_object(gobject, object)
      gobject = self.get_object(gobject) if gobject.kind_of?(String)
      if object
        @attached_objects[gobject] = object
      else
        @attached_objects.delete(gobject)
      end      
    end
    
    
    ## TODO: Everything below here is still being reworked and may end up in other classes
    def self.open
      self.new.open
    end
    def open_view(view_class)
      @view = view_class.new(self, @model)
      self          # return self
    end
  end
end