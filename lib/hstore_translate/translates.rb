module HstoreTranslate
  module Translates
    SUFFIX = "_translations".freeze

    def translates(*attrs)
      include InstanceMethods

      class_attribute :translated_attrs, :permitted_translated_attributes, :translation_ready_attrs
      alias_attribute :translated_attribute_names, :translated_attrs

      self.translated_attrs = attrs
      # translation_ready attributes defaults to all, can be a reduced set with translation_ready_with :attrs
      self.translation_ready_attrs = attrs

      self.permitted_translated_attributes = [
        *self.ancestors
          .select {|klass| klass.respond_to?(:permitted_translated_attributes) }
          .map(&:permitted_translated_attributes),
        *attrs.product(I18n.available_locales)
          .map { |attribute, locale| :"#{attribute}_#{locale}" }
      ].flatten.compact

      attrs.each do |attr_name|
        serialize "#{attr_name}#{SUFFIX}", ActiveRecord::Coders::Hstore unless HstoreTranslate::native_hstore?

        define_method attr_name do
          read_hstore_translation(attr_name)
        end

        define_method "#{attr_name}=" do |value|
          write_hstore_translation(attr_name, value)
        end

        define_singleton_method "with_#{attr_name}_translation" do |value, locale = I18n.locale|
          quoted_translation_store = connection.quote_column_name("#{attr_name}#{SUFFIX}")
          where("#{quoted_translation_store} @> hstore(:locale, :value)", locale: locale, value: value)
        end
      end

      send(:prepend, ActiveRecordWithHstoreTranslate)
    end

    def translates?
      included_modules.include?(InstanceMethods)
    end

    def translation_ready_with(*attrs)
      # set the translation ready attributes so they can be checked
      class_attribute :translation_ready_attrs
      self.translation_ready_attrs = attrs
    end
  end
end
