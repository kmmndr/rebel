module Rebel::SQL
  attr_reader :conn

  def exec(query)
    conn.exec(query)
  end

  def create_table(table_name, desc)
    exec(SQL.create_table(table_name, desc))
  end

  def select(*fields, from: nil, where: nil, inner: nil, left: nil, right: nil)
    exec(SQL.select(*fields,
                    from: from,
                    where: where,
                    inner: inner,
                    left: left,
                    right: right))
  end

  def insert_into(table_name, *rows)
    exec(SQL.insert_into(table_name, *rows))
  end

  def update(table_name, set: nil, where: nil, inner: nil, left: nil, right: nil)
    exec(SQL.update(table_name, set: set, where: where, inner: inner, left: left, right: right))
  end

  def delete_from(table_name, where: nil, inner: nil, left: nil, right: nil)
    exec(SQL.delete_from(table_name, where: where, inner: inner, left: left, right: right))
  end

  def truncate(table_name)
    exec(SQL.truncate(table_name))
  end

  def count(*n)
    SQL.count(*n)
  end

  def join(table, on: nil)
    SQL.join(table, on: on)
  end

  def outer_join(table, on: nil)
    SQL.outer_join(table, on: on)
  end

  class Raw < String
    def as(n)
      Raw.new(self + " AS #{SQL.name(n)}")
    end

    def as?(n)
      n ? as(n) : self
    end

    def on(clause)
      Raw.new(self + " ON #{SQL.and_clause(clause)}")
    end

    def on?(clause)
      clause ? on(clause) : self
    end
  end

  class << self
    def raw(str)
      Raw.new(str)
    end

    def create_table(table_name, desc)
      <<-SQL
      CREATE TABLE #{SQL.name(table_name)} (
        #{SQL.list(desc.map { |k, v| "#{SQL.name(k)} #{v}" })}
      );
      SQL
    end

    def select(*fields, from: nil, where: nil, inner: nil, left: nil, right: nil)
      <<-SQL
      SELECT #{names(*fields)} FROM #{name(from)}
      #{SQL.inner?(inner)}
      #{SQL.left?(left)}
      #{SQL.right?(right)}
      #{SQL.where?(where)};
      SQL
    end

    def insert_into(table_name, *rows)
      <<-SQL
      INSERT INTO #{SQL.name(table_name)} (#{SQL.names(*rows.first.keys)})
      VALUES #{SQL.list(rows.map { |r| "(#{SQL.values(*r.values)})" })};
      SQL
    end

    def update(table_name, set: nil, where: nil, inner: nil, left: nil, right: nil)
      fail ArgumentError if set.nil?

      <<-SQL
      UPDATE #{SQL.name(table_name)}
      SET #{SQL.assign_clause(set)}
      #{SQL.inner?(inner)}
      #{SQL.left?(left)}
      #{SQL.right?(right)}
      #{SQL.where?(where)};
      SQL
    end

    def delete_from(table_name, where: nil, inner: nil, left: nil, right: nil)
      <<-SQL
      DELETE FROM #{SQL.name(table_name)}
      #{SQL.inner?(inner)}
      #{SQL.left?(left)}
      #{SQL.right?(right)}
      #{SQL.where?(where)};
      SQL
    end

    def truncate(table_name)
      <<-SQL
      TRUNCATE #{SQL.name(table_name)};
      SQL
    end

    ## Functions

    def count(*n)
      raw("COUNT(#{names(*n)})")
    end

    def join(table, on: nil)
      raw("JOIN #{name(table)}").on?(on)
    end

    def outer_join(table, on: nil)
      raw("OUTER JOIN #{name(table)}").on?(on)
    end

    ## Support

    def name(name)
      return name if name.is_a?(Raw)
      return raw('*') if name == '*'

      name.to_s.split('.').map { |e| "\"#{e}\"" }.join('.')
    end

    def names(*names)
      list(names.map { |k| name(k) })
    end

    def list(*items)
      items.join(', ')
    end

    def value(v)
      case v
      when Raw then v
      when String then raw "'#{v.tr("'", "''")}'"
      when Fixnum then raw v.to_s
      when nil then raw 'NULL'
      else fail NotImplementedError, v.inspect
      end
    end

    def values(*values)
      list(values.map { |v| value(v) })
    end

    def name_or_value(item)
      item.is_a?(Symbol) ? name(item) : value(item)
    end

    def equal(l, r)
      "#{name_or_value(l)} = #{name_or_value(r)}"
    end

    def assign_clause(clause)
      list(clause.map { |k, v| equal(k, v) })
    end

    def and_clause(clause)
      return clause if clause.is_a?(Raw) || clause.is_a?(String)

      clause.map do |e|
        case e
        when Array then "#{name(e[0])} = #{name_or_value(e[1])}"
        when Raw, String then e
        else fail NotImplementedError, e.class
        end
      end.join(' AND ')
    end

    def where?(clause)
      return "WHERE #{clause}" if clause.is_a?(Raw) || clause.is_a?(String)

      (clause && clause.any?) ? "WHERE #{SQL.and_clause(clause)}" : nil
    end

    def inner?(join)
      join ? "INNER #{join}" : nil
    end

    def left?(join)
      join ? "LEFT #{join}" : nil
    end

    def right?(join)
      join ? "RIGHT #{join}" : nil
    end
  end
end