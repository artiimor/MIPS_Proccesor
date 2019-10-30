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
      	Reset : in std_logic; -- Reset as�ncrono a nivel alto
      	A1    : in std_logic_vector(4 downto 0);   -- Direcci�n para el puerto Rd1
      	Rd1   : out std_logic_vector(31 downto 0); -- Dato del puerto Rd1
      	A2    : in std_logic_vector(4 downto 0);   -- Direcci�n para el puerto Rd2
      	Rd2   : out std_logic_vector(31 downto 0); -- Dato del puerto Rd2
      	A3    : in std_logic_vector(4 downto 0);   -- Direcci�n para el puerto Wd3
      	Wd3   : in std_logic_vector(31 downto 0);  -- Dato de entrada Wd3
      	We3   : in std_logic -- Habilitaci�n de la escritura de Wd3
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

--declaracion de se�ales
signal regdst, branch, memread, memtoreg, memwrite, alusrc, regwrite, zflag, and_s, cond_j : std_logic;
signal aluop :std_logic_vector (2 downto 0);
signal alucontrol : std_logic_vector (3 downto 0);
signal a3 : std_logic_vector(4 downto 0); --de los registros.
signal rd1, rd2, aluaux, alures, wd3, sigextend, sigextend_j,  suma4, PCSalida, sl2, sl2_j, muxpc, sumapc : std_logic_vector (31 downto 0);

--para el registro 0
signal suma4_0, instruccion_0 : std_logic_vector(31 downto 0);

--Para el primer registro todas las se�ales
signal regwrite_1, memtoreg_1, branch_1, memread_1, memwrite_1, regdst_1, alusrc_1 : std_logic;
signal aluop_1: std_logic_vector(2 downto 0);
signal suma4_1, rd1_1, rd2_1, sigextend_1: std_logic_vector(31 downto 0);
signal muxwr0_1, muxwr1_1: std_logic_vector(4 downto 0);

--Para el segundo registro
signal branch_2, memread_2, memwrite_2, memtoreg_2, regwrite_2 : std_logic;
signal zflag_2 : std_logic;
signal alures_2, sumapc_2, rd2_2: std_logic_vector(31 downto 0);
signal a3_2: std_logic_vector(4 downto 0);

--Para el tercer registro
signal regwrite_3, memtoreg_3 : std_logic;
signal rd_3, alures_3 : std_logic_vector(31 downto 0);
signal a3_3: std_logic_vector(4 downto 0);

--Para los multiplexores de la forwarding unity
signal aluin_1, aluin_2 : std_logic_vector(31 downto 0);
signal mux_registerrd, mux_registerrd_2, mux_registerrd_3: std_logic_vector(4 downto 0);

-- Para rs, rt y rd en el caso _1
signal rs_1, rt_1, rd_1 : std_logic_vector(4 downto 0);

begin 

--portmap del banco de registros
u1: reg_bank port map(
	Clk   => Clk,
 	Reset => Reset,
  	A1    => instruccion_0(25 downto 21),
  	Rd1   => rd1, --se�al
  	A2    => instruccion_0 (20 downto 16),
  	Rd2   => rd2, --se�al
  	A3    => a3_3, --se�al (mux)
	Wd3   => wd3, --se�al (mux)
 	We3   => regwrite_3 --se�al
);

--portmap de la alu
u2: alu port map(
	OpA     => aluin_1, --antes era rd1_1
  	OpB     => aluaux, --se�al (mux)
	Control => alucontrol,
  	Result  => alures,
  	ZFlag   => zflag
);

u3: control_unit port map(
	OpCode  => instruccion_0(31 downto 26),
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
	ALUOp  => aluop_1,
	Funct  => sigextend_1(5 downto 0),
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
		--registro 0
		suma4_0   <= X"00000000";
		instruccion_0 <= X"00000000";
		--registro1
		regwrite_1 <= '0';
		memtoreg_1 <= '0';
		branch_1 <= '0';
		memread_1 <= '1';
		memwrite_1 <= '0';
		regdst_1 <= '0';
		alusrc_1 <= '0';
		aluop_1 <= "000";
		suma4_1 <= X"00000000";
		
		rd1_1 <= X"00000000";
		rd2_1 <= X"00000000";
		sigextend_1 <= X"00000000";
		
		muxwr0_1 <= "00000";
		muxwr1_1 <= "00000";
		rs_1 <= "00000";
		rt_1 <= "00000";
		rd_1 <= "00000";
		
		--Para el segundo registro
    	branch_2 <= '0';
    	memread_2 <= '1';
    	memwrite_2 <= '0';
    	zflag_2 <= '0';
   		alures_2 <= X"00000000";
   		sumapc_2 <= X"00000000";
   		a3_2 <= "00000";
   		regwrite_2 <= '0';
   		memtoreg_2 <= '0';
   		rd2_2 <= X"00000000";
    
  		--Para el tercer registro
  		regwrite_3 <= '0';
 		memtoreg_3 <= '0';
  		rd_3 <= X"00000000";
  		alures_3 <= X"00000000";
  		a3_3 <= "00000";
    
	elsif rising_edge(Clk) then --Tenemos en cuenta el nop
		
		DWrEn      <= memwrite_2;
		DRdEn	   <= memread_2;
		DAddr 	   <= alures_2;
		DDataOut   <= rd2_2;
		IAddr      <= muxpc;
		--registro 0
	  	suma4_0   <= suma4;
		
		--registro1. Tenemos en cuenta el caso de las instrucciones lw
		if (instruccion_0(25 downto 21) = rt_1 or instruccion_0(20 downto 26) = rt_1) and memwrite_1 = '1' then
			regwrite_1 <= '0';
			memwrite_1 <= '0';
		else
			regwrite_1 <= regwrite;
			memwrite_1 <= memwrite;
			PCSalida <= muxpc;
			instruccion_0 <= IDataIn;
		end if;
		memtoreg_1 <= memtoreg;
		branch_1 <= branch;
		memread_1 <= memread;
		regdst_1 <= regdst;
		alusrc_1 <= alusrc;
		aluop_1 <= aluop;
		suma4_1 <= suma4_0;
		
		rd1_1 <= rd1;
		rd2_1 <= rd2;
		
		rs_1 <= instruccion_0(25 downto 21);
		rt_1 <= instruccion_0(20 downto 16);
		rd_1 <= instruccion_0(15 downto 11);
		
		
		muxwr0_1 <= instruccion_0 (20 downto 16);
		muxwr1_1 <= instruccion_0 (15 downto 11);
		
		--Para el segundo registro
    	branch_2 <= branch_1;
    	memread_2 <= memread_1;
    	memwrite_2 <= memwrite_1;
    	memtoreg_2 <= memtoreg_1;
    	regwrite_2 <= regwrite_1;
    	zflag_2 <= zflag;
    
    	alures_2 <= alures;
    	sumapc_2 <= sumapc;
    	a3_2 <= a3;
		rd2_2 <= rd2_1;
		
		mux_registerrd_2 <= mux_registerrd;
		
    
    	--Para el tercer registro
    	regwrite_3 <= regwrite_2;
    	memtoreg_3 <= memtoreg_2;
    	rd_3 <= DDataIn;
    	alures_3 <= alures_2;
    	a3_3 <= a3_2;
    	
    	mux_registerrd_3 <= mux_registerrd_2;

		if IDataIn = X"00000000" then
			instruccion_0 <= X"11111111";
			
	    	end if;
		if instruccion_0 = X"11111111" then
			sigextend_1 <= X"00000000";
		else
			sigextend_1 <= sigextend;
		end if;
		
		
	end if;
end process;
     
		
--Hacemos el extensor de signo
--sigextend <= std_logic_vector(resize(signed(instruccion_0(15 downto 0)), sigextend'length));

sigextend <= "1111111111111111" & instruccion_0(15 downto 0) when instruccion_0(15) = '1' else "0000000000000000" & instruccion_0(15 downto 0);
--Hacemos el extensor de signo para j
sigextend_j <= "111111" & instruccion_0(25 downto 0) when instruccion_0(25) = '1' else "000000" & instruccion_0(25 downto 0);

--Hacemos el desplazamiento a la izquierda para el pc
sl2 <= sigextend_1(29 downto 0) & "00";
--Hacemos el desplazamiento a la izquierda y aniadimos pc4 para j
sl2_j <= suma4(31 downto 28) & sigextend_j(25 downto 0) & "00";
--hacemos el and
and_s <= '1' when (branch_2 = '1' and zflag_2 = '1') else '0';
--hacemos la j en el caso de que la instruccion sea la j
cond_j <= '1' when (instruccion_0(31 downto 26)  = "000010") else '0';
--Hacemos los multiplexores
a3 <= muxwr1_1 when regdst_1 = '1' else muxwr0_1; --pasar por registro
aluaux <= sigextend_1 when alusrc_1 = '1' else aluin_2; --antes aluin_2 era src_1
wd3 <= DDataIn when memtoreg_3 = '1' else alures_3;
muxpc <= sumapc_2 when and_s = '1' else
                  sl2_j when cond_j = '1' else suma4;
                  
--multiplexores de la fowarding unity
aluin_1 <= wd3 when (regwrite_3 = '1' and a3_3 /= 0 and a3_3 = IDataIn(25 downto 21)) else a3_3 when (regwrite_2 = '1' and a3_2 /= 0 and a3_2 = instruccion_0(25 downto 21)) else rd1_1;
aluin_2 <= wd3 when (regwrite_3 = '1' and mux_registerrd_3 /= 0 and mux_registerrd_3 = instruccion_0(20 downto 16)) else alures_2 when (regwrite_2 = '1' and mux_registerrd_2 /= 0 and mux_registerrd_2 = instruccion_0(20 downto 16)) else rd2_1;

mux_registerrd <= rt_1 when alucontrol = "000" or alucontrol = "001" or alucontrol = "010" or alucontrol = "011" else instruccion_0(15 downto 11);

--cosas que calculo
suma4 <= PCSalida + 4; --Al ciclo se le suma 4 a la instrucci�n
sumapc <= sl2 + suma4_1;
 
end architecture;

