require_relative '../../lib/gmvc'

class CHBView < GMVC::View

  def self.glade_filename
    "chb.glade"
  end
  def self.window_name
    "chb_window"
  end
  def unhandled_signal(signal)
    puts "Unhandled signal encountered: " + signal
  end
  def init_window
    super
    self.init_classes
    self.init_methods
  end
  def init_classes
    @classes = @builder.get_object("classes")
    @classes.model = @model.classes_treestore
    @classes.headers_visible = false
    @classes_renderer = Gtk::CellRendererText.new
    @classes_column = Gtk::TreeViewColumn.new("Class Name", @classes_renderer, :text => 0)
    @classes.append_column(@classes_column)
    @classes.selection.set_select_function do |selection, classes_model, path, currently_selected|
      class_iter = classes_model.get_iter(path)
      return true if class_iter.nil?
      @controller.on_class_selected(self, @methods, class_iter, currently_selected)
    end
    def methods_type
      :instance_methods
    end
  end
  
  
  def init_methods
    @methods = @builder.get_object("methods")
    # @methods.model = @model.methods_liststore
    @methods.headers_visible = false
    @methods_renderer = Gtk::CellRendererText.new
    @methods_column = Gtk::TreeViewColumn.new("Method Name", @methods_renderer, :text => 0)
    @methods.append_column(@methods_column)
  end
end

class CHBModel < GMVC::Model
  attr_reader :classes_treestore, :methods_liststores
  def initialize
    super
    @methods_liststores = {}
    self.init_classes_treestore
  end
  def init_classes_treestore
    @classes_treestore = Gtk::TreeStore.new(String)
    @classes = {nil => Hash.new}
    ObjectSpace.each_object(Class) { |cls| self.store_class(cls) }
    self.load_treestore_from_hash(@classes_treestore, nil, @classes[nil]) {|iter, cls| iter[0] = cls.name } 
    @classes_treestore.set_sort_column_id(0)
  end
  
  def load_treestore_from_hash(treestore, parent, hsh, &proc)
    hsh.each do |key, value|
      iter = treestore.append(parent)
      proc.call(iter, key)
      self.load_treestore_from_hash(treestore, iter, value, &proc)
    end
  end
  
  def store_class(cls)
    return @classes[cls] if @classes.include?(cls)
    hsh = self.store_class(cls.superclass)
    hsh[cls] = Hash.new
    @classes[cls] = hsh[cls]
  end
  
  def new_methods_liststore_for_class(class_name, methods_type)
    liststore = Gtk::ListStore.new(String, String)
    cls = Kernel.const_get(class_name)
    cls.public_instance_methods(false).each do |mth| 
      iter = liststore.append
      iter[0] = "+ " + mth.to_s
      iter[1] = mth.to_s
    end
    cls.private_instance_methods(false).each do |mth| 
      iter = liststore.append
      iter[0] = "- " + mth.to_s
      iter[1] = mth.to_s
    end
    cls.protected_instance_methods(false).each do |mth| 
      iter = liststore.append
      iter[0] = "# " + mth.to_s
      iter[1] = mth.to_s
    end
    liststore.set_sort_column_id(0)
    liststore
  end
  def register_methods_view_for_class(view, class_iter, methods_type)
    key = class_iter[0] + '#' + methods_type.to_s
    if !@methods_liststores.include?(key)
      liststore = self.new_methods_liststore_for_class(class_iter[0], methods_type)
      @methods_liststores[key] = {liststore => []}
    end
    @methods_liststores[key].values.first << view
    view.model = @methods_liststores[key].keys.first
    true
  end
  def unregister_methods_view_for_class(view, class_iter, methods_type)
    key = class_iter[0] + '#' + methods_type.to_s
    return true if !@methods_liststores.include?(key)
    puts "problem" if @methods_liststores[key].values.first.delete(view).nil?
    @methods_liststores.delete(key) if @methods_liststores[key].values.first.size == 0
    view.model = nil
    true
  end
end

class CHBWindow < GMVC::Controller
  @@model = CHBModel.new    # All views will share the same model
  def initialize
    @model = @@model
  end
  def default_view_class
    CHBView
  end
  def on_quit_action_activate
    puts "button clicked!"
    @view.close
  end
  def on_class_selected(view, treeview, class_iter, currently_selected)
    return false if !self.save_changes
    if !currently_selected
      @model.register_methods_view_for_class(treeview, class_iter, view.methods_type)
    else
      @model.unregister_methods_view_for_class(treeview, class_iter, view.methods_type)
    end
  end
  def save_changes
    true
  end
end

window = CHBWindow.open
Gtk.main