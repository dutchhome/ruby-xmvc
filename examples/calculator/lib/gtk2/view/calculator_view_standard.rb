module GMVCApp
  class CalculatorViewStandard < GMVC::View
    
    def initialize(*args)
      super
      @entry = @builder.get_object("entry")
      @entry.editable = false
      @model.set_attribute_reaction("entry", @entry) { |value| @entry.text = value }
    end
    def about_to_close
      false
    end
  end
end