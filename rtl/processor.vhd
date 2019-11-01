--------------------------------------------------------------------------------
-- Procesador MIPS con pipeline curso Arquitectura 2019-2020
--
-- Aitor Melero y Arturo Morcillo 1361
--
--------------------------------------------------------------------------------

library ieee;
use ieee.std_logic_1164.all;
use ieee.std_logic_unsigned.all;
use ieee.numeric_std.all; 

entity processor is
   port(
      Clk         : in  std_logic; -- Reloj activo en flanco subida
      Reset       : in  std_logic; -- Reset asincrono activo nivel alto
      -- Instruction memory
      IAddr      : out std_logic_vector(31 downto 0); -- Direccion Instr
      IDataIn    : in  std_logic_vector(31 downto 0); -- Instruccion leida
      -- Data memory
      DAddr      : out std_logic_vector(31 downto 0); -- Direccion
      DRdEn      : out std_logic;                     -- Habilitacion lectura
      DWrEn      : out std_logic;                     -- Habilitacion escritura
      DDataOut   : out std_logic_vector(31 downto 0); -- Dato escrito
      DDataIn    : in  std_logic_vector(31 downto 0)  -- Dato leido
   );
 end processor;

architecture rtl of processor is 

--instanciacion de componentes:
--Registro
component reg_bank
    port (
	Clk   : in std_logic; -- Reloj activo en flanco de subida
      	Reset : in std_logic; -- Reset asíncrono a nivel alto
      	A1    : in std_logic_vector(4 downto 0);   -- Dirección para el puerto Rd1
      	Rd1   : out std_logic_vector(31 downto 0); -- Dato del puerto Rd1
      	A2    : in std_logic_vector(4 downto 0);   -- Dirección para el puerto Rd2
      	Rd2   : out std_logic_vector(31 downto 0); -- Dato del puerto Rd2
      	A3    : in std_logic_vector(4 downto 0);   -- Dirección para el puerto Wd3
      	Wd3   : in std_logic_vector(31 downto 0);  -- Dato de entrada Wd3
      	We3   : in std_logic -- Habilitación de la escritura de Wd3
	); 
end component;

--ALU
component alu
	Port (
		OpA     : in  std_logic_vector (31 downto 0); -- Operando A
  		OpB     : in  std_logic_vector (31 downto 0); -- Operando B
		Control : in  std_logic_vector ( 3 downto 0); -- Codigo de control=op. a ejecutar
		Result  : out std_logic_vector (31 downto 0); -- Resultado
		ZFlag   : out std_logic                       -- Flag Z
		);
end component;

--Unidad de control
component control_unit
	Port (
		-- Entrada = codigo de operacion en la instruccion:
      		OpCode  : in  std_logic_vector (5 downto 0); --Cosas que comprobamos (input)
     		 -- Seniales para el PC
      		Branch : out  std_logic; -- 1 = Ejecutandose instruccion branch
  	    -- Seniales relativas a la memoria
      		MemToReg : out  std_logic; -- 1 = Escribir en registro la salida de la mem.
      		MemWrite : out  std_logic; -- Escribir la memoria
      		MemRead  : out  std_logic; -- Leer la memoria
      		-- Seniales para la ALU
      		ALUSrc : out  std_logic;                     -- 0 = oper.B es registro, 1 = es valor inm.
      		ALUOp  : out  std_logic_vector (2 downto 0); -- Tipo operacion para control de la ALU
      		-- Seniales para el GPR
      		RegWrite : out  std_logic; -- 1=Escribir registro
      		RegDst   : out  std_logic  -- 0=Reg. destino es rt, 1=rd
		);
end component;

--el alucontrol
component alu_control
	Port(
	    -- Entradas:
 	    ALUOp  : in std_logic_vector (2 downto 0); -- Codigo de control desde la unidad de control
		Funct  : in std_logic_vector (5 downto 0); -- Campo "funct" de la instruccion
		-- Salida de control para la ALU:
		ALUControl : out std_logic_vector (3 downto 0) -- Define operacion a ejecutar por la ALU
	);
end component;

--Fin de instanciacion de componentes

--declaracion de señales
signal regdst, branch, memread, memtoreg, memwrite, alusrc, regwrite, zflag, and_s, cond_j : std_logic;
signal aluop :std_logic_vector (2 downto 0);
signal alucontrol : std_logic_vector (3 downto 0);
signal a3 : std_logic_vector(4 downto 0); --de los registros.
signal rd1, rd2, aluaux, alures, wd3, sigextend, sigextend_j,  suma4, PCSalida, sl2, sl2_j, muxpc, sumapc, rd1_mux, rd2_mux : std_logic_vector (31 downto 0);

--para el registro 0
signal suma4_IFID, instruccion_IFID : std_logic_vector(31 downto 0);

--Para el primer registro todas las señales
signal regwrite_IDEX, memtoreg_IDEX, branch_IDEX, memread_IDEX, memwrite_IDEX, regdst_IDEX, alusrc_IDEX : std_logic;
signal aluop_IDEX: std_logic_vector(2 downto 0);
signal suma4_IDEX, rd1_IDEX, rd2_IDEX, sigextend_IDEX: std_logic_vector(31 downto 0);
signal muxwr0_IDEX, muxwr1_IDEX: std_logic_vector(4 downto 0);

--Para el segundo registro
signal branch_EXMEM, memread_EXMEM, memwrite_EXMEM, memtoreg_EXMEM, regwrite_EXMEM : std_logic;
signal zflag_EXMEM : std_logic;
signal alures_EXMEM, sumapc_EXMEM, rd2_EXMEM: std_logic_vector(31 downto 0);
signal a3_EXMEM: std_logic_vector(4 downto 0);

--Para el tercer registro
signal regwrite_MEMWB, memtoreg_MEMWB : std_logic;
signal rd_MEMWB, alures_MEMWB : std_logic_vector(31 downto 0);
signal a3_MEMWB: std_logic_vector(4 downto 0);

--Para los multiplexores de la forwarding unity
signal aluin_1, aluin_2, instruccion_IDEX : std_logic_vector(31 downto 0);
signal mux_registerrd, mux_registerrd_EXMEM, mux_registerrd_MEMWB: std_logic_vector(4 downto 0);

-- Para rs, rt y rd en el caso _IDEX
signal rs_IDEX, rt_IDEX, rd_IDEX, rs_EXMEM, rd_EXMEM, rt_EXMEM : std_logic_vector(4 downto 0);

signal aux : std_logic;

begin 

--portmap del banco de registros
u1: reg_bank port map(
	Clk   => Clk,
 	Reset => Reset,
  	A1    => instruccion_IFID(25 downto 21),
  	Rd1   => rd1, --señal
  	A2    => instruccion_IFID (20 downto 16),
  	Rd2   => rd2, --señal
  	A3    => a3_MEMWB, --señal (mux)
	Wd3   => wd3, --señal (mux)
 	We3   => regwrite_MEMWB --señal
);

--portmap de la alu
u2: alu port map(
	OpA     => aluin_1, --antes era rd1_IDEX
  	OpB     => aluaux, --señal (mux)
	Control => alucontrol,
  	Result  => alures,
  	ZFlag   => zflag
);

u3: control_unit port map(
	OpCode  => instruccion_IFID(31 downto 26),
	Branch => branch,
	MemToReg => memtoreg,
	MemWrite => memwrite,
	MemRead => memread,
	ALUSrc => alusrc,
	ALUOp  => aluop,
	RegWrite => regwrite,
	RegDst   => regdst
);

u4: alu_control port map(
	ALUOp  => aluop_IDEX,
	Funct  => sigextend_IDEX(5 downto 0),
	ALUControl => alucontrol

);

process(Reset, Clk) begin
	if Reset = '1' then
		PCSalida <= X"00000000";
		DWrEn      <= '0';
		DRdEn	   <= '1';
		DAddr 	   <= X"00000000";
		DDataOut   <= X"00000000";
		IAddr      <= X"00000000";

		aux <= '0';
		--registro 0
		suma4_IFID   <= X"00000000";
		instruccion_IFID <= X"00000000";
		--registro1
		regwrite_IDEX <= '0';
		memtoreg_IDEX <= '0';
		branch_IDEX <= '0';
		memread_IDEX <= '1';
		memwrite_IDEX <= '0';
		regdst_IDEX <= '0';
		alusrc_IDEX <= '0';
		aluop_IDEX <= "000";
		suma4_IDEX <= X"00000000";
		
		rd1_IDEX <= X"00000000";
		rd2_IDEX <= X"00000000";
		sigextend_IDEX <= X"00000000";
		
		muxwr0_IDEX <= "00000";
		muxwr1_IDEX <= "00000";
		rs_IDEX <= "00000";
		rt_IDEX <= "00000";
		rd_IDEX <= "00000";
		
		--Para el segundo registro
    	branch_EXMEM <= '0';
    	memread_EXMEM <= '1';
    	memwrite_EXMEM <= '0';
    	zflag_EXMEM <= '0';
   		alures_EXMEM <= X"00000000";
   		sumapc_EXMEM <= X"00000000";
   		a3_EXMEM <= "00000";
   		regwrite_EXMEM <= '0';
   		memtoreg_EXMEM <= '0';
   		rd2_EXMEM <= X"00000000";
    
  		--Para el tercer registro
  		regwrite_MEMWB <= '0';
 		memtoreg_MEMWB <= '0';
  		rd_MEMWB <= X"00000000";
  		alures_MEMWB <= X"00000000";
  		a3_MEMWB <= "00000";
    
	elsif rising_edge(Clk) then --Tenemos en cuenta el nop
		
		--registro1. Tenemos en cuenta el caso de las instrucciones lw y despues leer de un registro. En ese caso introducimos un nop
		if memtoreg_IDEX = '1' and regwrite = '1' and (rt_IDEX = instruccion_IFID(25 downto 21) or rt_IDEX = instruccion_IFID(20 downto 16)) then
			regwrite_IDEX <= '0';
			aux <= '1';
		else
			regwrite_IDEX <= regwrite;
			memwrite_IDEX <= memwrite;
			PCSalida <= muxpc;
			
			IAddr      <= muxpc;
			--registro 0
	  		suma4_IFID   <= suma4;
			DWrEn      <= memwrite_EXMEM;
			DRdEn	   <= memread_EXMEM;
			DAddr 	   <= alures_EXMEM;
			DDataOut   <= rd2_EXMEM;
			instruccion_IDEX <= instruccion_IFID;
		if IDataIn = X"00000000" then
		instruccion_IFID <= X"11111111";
		else
		instruccion_IFID <= IDataIn;
	    	end if;

		

		end if;
		memtoreg_IDEX <= memtoreg;
		branch_IDEX <= branch;
		memread_IDEX <= memread;
		regdst_IDEX <= regdst;
		alusrc_IDEX <= alusrc;
		aluop_IDEX <= aluop;
		suma4_IDEX <= suma4_IFID;
		
		rd1_IDEX <= rd1_mux;
		rd2_IDEX <= rd2_mux;
		
		rs_IDEX <= instruccion_IFID(25 downto 21);
		rt_IDEX <= instruccion_IFID(20 downto 16);
		rd_IDEX <= instruccion_IFID(15 downto 11);
		
		rs_EXMEM <= rs_IDEX;
		rt_EXMEM <= rt_IDEX;
		rd_EXMEM <= rd_IDEX;
		
		
		muxwr0_IDEX <= instruccion_IFID (20 downto 16);
		muxwr1_IDEX <= instruccion_IFID (15 downto 11);
		
		--Para el segundo registro
    	branch_EXMEM <= branch_IDEX;
    	memread_EXMEM <= memread_IDEX;
    	memwrite_EXMEM <= memwrite_IDEX;
    	memtoreg_EXMEM <= memtoreg_IDEX;
    	regwrite_EXMEM <= regwrite_IDEX;
    	zflag_EXMEM <= zflag;
    
    	alures_EXMEM <= alures;
    	sumapc_EXMEM <= sumapc;
    	a3_EXMEM <= a3;
		rd2_EXMEM <= rd2_IDEX;
		
		mux_registerrd_EXMEM <= mux_registerrd;
		
    
    	--Para el tercer registro
    	regwrite_MEMWB <= regwrite_EXMEM;
    	memtoreg_MEMWB <= memtoreg_EXMEM;
    	rd_MEMWB <= DDataIn;
    	alures_MEMWB <= alures_EXMEM;
    	a3_MEMWB <= a3_EXMEM;
    	
    	mux_registerrd_MEMWB <= mux_registerrd_EXMEM;

		if instruccion_IFID = X"11111111" then
			sigextend_IDEX <= X"00000000";
		else
			sigextend_IDEX <= sigextend;
		end if;
		
		
	end if;
end process;
     
		
--Hacemos el extensor de signo
--sigextend <= std_logic_vector(resize(signed(instruccion_IFID(15 downto 0)), sigextend'length));

sigextend <= "1111111111111111" & instruccion_IFID(15 downto 0) when instruccion_IFID(15) = '1' else "0000000000000000" & instruccion_IFID(15 downto 0);
--Hacemos el extensor de signo para j
sigextend_j <= "111111" & instruccion_IFID(25 downto 0) when instruccion_IFID(25) = '1' else "000000" & instruccion_IFID(25 downto 0);

--Hacemos el desplazamiento a la izquierda para el pc
sl2 <= sigextend_IDEX(29 downto 0) & "00";
--Hacemos el desplazamiento a la izquierda y aniadimos pc4 para j
sl2_j <= suma4(31 downto 28) & sigextend_j(25 downto 0) & "00";
--hacemos el and
and_s <= '1' when (branch_EXMEM = '1' and zflag_EXMEM = '1') else '0';
--hacemos la j en el caso de que la instruccion sea la j
cond_j <= '1' when (instruccion_IFID(31 downto 26)  = "000010") else '0';
--Hacemos los multiplexores
a3 <= muxwr1_IDEX when regdst_IDEX = '1' else muxwr0_IDEX; --pasar por registro
aluaux <= sigextend_IDEX when alusrc_IDEX = '1' else aluin_2; --antes aluin_2 era src_IDEX
wd3 <= DDataIn when memtoreg_MEMWB = '1' else alures_MEMWB;
muxpc <= sumapc_EXMEM when and_s = '1' else
                  sl2_j when cond_j = '1' else suma4;
                  
--Multiplexores encargados de los riesgos registro a registro
aluin_1 <= alures_EXMEM when (regwrite_EXMEM = '1' and a3_EXMEM /= 0 and a3_EXMEM = rs_IDEX) else wd3 when (regwrite_MEMWB = '1' and a3_MEMWB /= 0 and a3_MEMWB = rs_IDEX) else rd1_IDEX;
-----------------------------------------------
---------FALLO EN ALUIN"-----------------------
-----------------------------------------------
aluin_2 <= alures_EXMEM when (regwrite_EXMEM = '1' and a3_EXMEM /= 0 and a3_EXMEM = rt_IDEX) else wd3 when (regwrite_MEMWB = '1' and a3_MEMWB /= 0 and a3_MEMWB = rt_IDEX) else rd2_IDEX;
--Multiplexores encargados de los riesgos registro a memoria
rd1_mux <= alures when (regwrite_IDEX = '1' and a3 /= 0 and a3 = instruccion_IFID(25 downto 21)) else alures_EXMEM when (regwrite_EXMEM = '1' and a3_EXMEM /= 0 and a3_EXMEM = instruccion_IFID(25 downto 21))  else alures_MEMWB when (regwrite_MEMWB = '1' and a3_MEMWB /= 0 and a3_MEMWB = instruccion_IFID(25 downto 21)) else rd1;
rd2_mux <= alures when (regwrite_IDEX = '1' and a3 /= 0 and a3 = instruccion_IFID(20 downto 16)) else alures_EXMEM when (regwrite_EXMEM = '1' and a3_EXMEM /= 0 and a3_EXMEM = instruccion_IFID(20 downto 16)) else alures_MEMWB when (regwrite_MEMWB = '1' and a3_MEMWB /= 0 and a3_MEMWB = instruccion_IFID(20 downto 16)) else rd2;

mux_registerrd <= instruccion_IFID(25 downto 21) when alucontrol = "000" or alucontrol = "001" or alucontrol = "010" or alucontrol = "011" else instruccion_IFID(15 downto 11);

--cosas que calculo
suma4 <= PCSalida + 4; --Al ciclo se le suma 4 a la instrucción
sumapc <= sl2 + suma4_IDEX;
 
end architecture;

