--------------------------------------------------------------------------------
-- Bloque de control para la ALU. Arq0 2019-2020.
--
-- Aitor Melero y Arturo Morcillo 1361
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;

entity alu_control is
   port (
      -- Entradas:
      ALUOp  : in std_logic_vector (2 downto 0); -- Codigo de control desde la unidad de control
      Funct  : in std_logic_vector (5 downto 0); -- Campo "funct" de la instruccion
      -- Salida de control para la ALU:
      ALUControl : out std_logic_vector (3 downto 0) -- Define operacion a ejecutar por la ALU
   );
end alu_control;

architecture rtl of alu_control is
   
begin

    --Asignamos las señales

    process(ALUOp, Funct) begin
        case ALUOp is --Con esto compruebo que la operacion es RType o es de otro tipò
            when "000" => --Para el caso de sw, lw, addi (queremos un add)
	             ALUControl <= "0000";
	          when "001" => --Para el caso de beq (queremos un sub)
	             ALUControl <= "0001";
	          when "010" => --para el caso de lui
		           ALUControl <= "1101";
	          when "011" => --para el slt
		            ALUControl <= "1010";
	          when others => --Para el caso de Rtype
	             case Funct is
	                when "100000" => --Operacion add
		                ALUControl <= "0000";
		              when "100100" => --Operacion and
		                ALUControl <= "0100";
		              when "100101" => --Operacion or
		                ALUControl <= "0111";
		              when "100010" => --Operacion sub
		                ALUControl <= "0001";
		              when "100110" => --Operacion xor
		                ALUControl <= "0110";
		              when others =>
		                ALUControl <= "1111";
          end case;
        end case;
    end process;
		
end architecture;
