module MacroTranspile
  module Functions
    private def transpile(method : Crystal::Def)
      CURRENT_CONTEXT.push({symbol: :def, node: method})
      @@log.debug("Def: #{method.name}, #{method.args}")

      name = method.name

      @@functions[name.to_s] = method

      args = method.args.map_with_index do |arg, i|
        assign(arg.name, arg)
        %(#{transpile arg} = $$#{i}).as(String)
      end

      CURRENT_CONTEXT.pop
      %(
// @FILE #{name}.txt
// @METHOD #{name}(#{method.args.join(", ")})
#{args.join("\n")}
#{transpile method.body}
)
    end

    private def transpile(arg : Crystal::Arg)
      io = IO::Memory.new
      io << "#{variable arg.name}"
      io << " = #{arg.default_value}" if arg.default_value
      io.to_s
    end

    private def transpile(call : Crystal::Call)
      @@log.debug("Call: #{call.name}, #{call.args}")

      method = call.name

      @@log.debug "#{call.obj} : #{call.obj.class}"

      case call.name
      when "+", "-", "*", "/", "<", ">", "=="
        obj = call.obj
        arg = call.args[0]

        obj = transpile call.obj if call.obj.class == Crystal::InstanceVar || call.obj.class == Crystal::Var
        arg = transpile call.args[0] if call.args[0].class == Crystal::InstanceVar || call.args[0].class == Crystal::Var
        "#{obj} #{call.name} #{arg}"
      when "[]"
        obj = call.obj
        arg = call.args[0]

        obj = transpile call.obj if call.obj.class == Crystal::InstanceVar || call.obj.class == Crystal::Var
        arg = transpile call.args[0] if call.args[0].class == Crystal::InstanceVar || call.args[0].class == Crystal::Var

        # args.map do |arg|
        #   arg = transpile arg if arg == Crystal::InstanceVar || arg == Crystal::Var
        # end

        obj.to_s.sub /\[\]/, "[#{arg}]"
        # obj.to_s + "[#{arg}]"
      else
        if @@functions[method.to_s]?
          args = call.args.map_with_index do |arg, i|
            arg = transpile arg if arg == Crystal::InstanceVar || arg == Crystal::Var
            arg
          end

          method_arguments = "#{method}_args = [#{args.join(",")}]"

          %(
// @CALL #{method}
EXEC("#{method}.txt","#{method}"#{',' if !args.empty?}#{args.map { |a| transpile a }.join ","})
)
        else
          args = transpile call.args

          if call.obj
            method = "#{call.obj}.#{method}"
          end

          "#{method.upcase}(#{args.join(", ")});"
        end
      end
    end
  end
end
