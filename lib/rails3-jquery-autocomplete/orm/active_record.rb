module Rails3JQueryAutocomplete
  module Orm
    module ActiveRecord
      def active_record_get_autocomplete_order(method, options, model=nil)
        order = options[:order]

        table_prefix = model ? "#{model.table_name}." : ""
        order || "LOWER(#{table_prefix}#{method}) ASC"
      end

      def active_record_get_autocomplete_items(parameters)
        model   = parameters[:model]
        term    = parameters[:term]
        options = parameters[:options]
        method  = options[:hstore] ? options[:hstore][:method] : parameters[:method]
        search_scope = options[:search_scope]
        scopes  = Array(options[:scopes])
        where   = options[:where]
        limit   = get_autocomplete_limit(options)
        order   = active_record_get_autocomplete_order(method, options, model)


        items = (::Rails::VERSION::MAJOR * 10 + ::Rails::VERSION::MINOR) >= 40 ? model.where(nil) : model.scoped

        scopes.each { |scope| items = items.send(scope) } unless scopes.empty?

        items = items.select(get_autocomplete_select_clause(model, method, options)) unless options[:full_model]

        if search_scope.blank?
          items = items.where(get_autocomplete_where_clause(model, term, method, options))
        else
          items = items.send(search_scope, get_autocomplete_term_for_like(term, options))
        end

        items = items.limit(limit).order(order)
        items = items.where(where) unless where.blank?

        items
      end

      def get_autocomplete_select_clause(model, method, options)
        table_name = model.table_name
        (["#{table_name}.#{model.primary_key}", "#{table_name}.#{method}"] + (options[:extra_data].blank? ? [] : options[:extra_data]))
      end

      def get_autocomplete_where_clause(model, term, method, options)
        table_name = model.table_name
        like_clause = (postgres?(model) ? 'ILIKE' : 'LIKE')
        if options[:hstore]
          ["LOWER(#{table_name}.#{method} -> '#{options[:hstore][:key]}') LIKE ?", get_autocomplete_term_for_like(term, options)]
        else
          ["LOWER(#{table_name}.#{method}) #{like_clause} ?", get_autocomplete_term_for_like(term, options)]
        end
      end

      def get_autocomplete_term_for_like(term, options)
        is_full_search = options[:full]
        "#{(is_full_search ? '%' : '')}#{term.downcase}%"
      end

      def postgres?(model)
        # Figure out if this particular model uses the PostgreSQL adapter
        model.connection.class.to_s.match(/PostgreSQLAdapter/)
      end
    end
  end
end
