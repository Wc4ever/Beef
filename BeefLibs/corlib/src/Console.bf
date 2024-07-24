using System.Text;
using System.IO;
using System.Threading;
using System.Threading.Tasks;

namespace System
{
	public static class Console
	{
		public enum CancelKind
		{
			CtrlC,
			CtrlBreak
		}

		public struct CancelInfo
		{
			public static Event<delegate void (CancelKind cancelKind, ref bool terminate)> sOnCancel ~ _.Dispose();
			public static bool sCancelEventRegistered;
		}

		static Encoding sInputEncoding;
		static Encoding sOutputEncoding;

		static Encoding InputEncoding
		{
			get
			{
				return sInputEncoding ?? Encoding.ASCII;
			}
			set
			{
				sInputEncoding = value;
			}
		}
		static Encoding OutputEncoding
		{
			get
			{
				return sOutputEncoding ?? Encoding.ASCII;
			}
			set
			{
				SetupOutStringEx();
				sOutputEncoding = value;
			}
		}
		
		static ConsoleColor sForegroundColor = .White;
		static ConsoleColor sBackgroundColor = .Black;

		static readonly ConsoleColor sOriginalForegroundColor = sForegroundColor;
		static readonly ConsoleColor sOriginalBackgroundColor = sBackgroundColor;

		public static ConsoleColor ForegroundColor
		{
			get { return sForegroundColor; }
			set { sForegroundColor = value; SetColors(); }
		}

		public static ConsoleColor BackgroundColor
		{
			get { return sBackgroundColor; }
			set { sBackgroundColor = value; SetColors(); }
		}
		
		const uint32 STD_INPUT_HANDLE  = (uint32)-10;
		const uint32 STD_OUTPUT_HANDLE = (uint32)-11;
		const uint32 STD_ERROR_HANDLE  = (uint32)-12;

		[CRepr]
		struct CONSOLE_SCREEN_BUFFER_INFO
		{
			public uint16[2] mSize;
			public uint16[2] mCursorPosition;
			public uint16 mAttributes;
			public uint16[4] mWindow;
			public uint16[2] mMaximumWindowSize;
		}

		[CRepr]
		struct COORD : this(int16 X, int16 Y)
		{
		}

		static void SetupOutStringEx()
		{
			OutString = => OutString_Ex;
		}

		static function void(StringView str) OutString = => OutString_Simple;

		public static extern void PutChar(char8 c);
		public static extern void ReopenHandles();

		static void OutString_Simple(StringView str)
		{
			for (var c in str.RawChars)
				PutChar(c);
		}

		static void OutString_Ex(StringView str)
		{
			Out.Write(str).IgnoreError();
		}

		public static ref Event<delegate void (CancelKind cancelKind, ref bool terminate)> OnCancel
		{
			get
			{
				if (!CancelInfo.sCancelEventRegistered)
				{
					CancelInfo.sCancelEventRegistered = true;
#if BF_PLATFORM_WINDOWS
					SetConsoleCtrlHandler(=> ConsoleCtrlHandler, true);
#endif
				}
				return ref CancelInfo.sOnCancel;
			}
		}

#if BF_PLATFORM_WINDOWS
		[CallingConvention(.Stdcall)]
		public static Windows.IntBool ConsoleCtrlHandler(int32 ctrlType)
		{
			bool terminate = true;
			if ((ctrlType == 0) || (ctrlType == 1))
				CancelInfo.sOnCancel((.)ctrlType, ref terminate);
			return terminate ? false : true;
		}

		//SetConsoleOutputCP set to CP_UTF8

		const uint32 ENABLE_LINE_INPUT = 0x0002;
		const uint32 ENABLE_ECHO_INPUT = 0x0004;

		[CLink, CallingConvention(.Stdcall)]
		static extern Windows.IntBool GetConsoleMode(Windows.Handle hConsoleHandle, out uint32 mode);

		[CLink, CallingConvention(.Stdcall)]
		static extern Windows.IntBool SetConsoleMode(Windows.Handle hConsoleHandle, uint32 mode);

		[CLink, CallingConvention(.Stdcall)]
		static extern Windows.IntBool SetConsoleTextAttribute(Windows.Handle hConsoleOutput, uint16 wAttributes);

		[CLink, CallingConvention(.Stdcall)]
		static extern Windows.IntBool GetConsoleScreenBufferInfo(Windows.Handle hConsoleOutput, out CONSOLE_SCREEN_BUFFER_INFO lpConsoleScreenBufferInfo);

		[CLink, CallingConvention(.Stdcall)]
		static extern Windows.Handle GetStdHandle(uint32 nStdHandle);

		[CLink, CallingConvention(.Stdcall)]
		static extern Windows.IntBool SetConsoleOutputCP(uint32 wCodePageID);

		[CallingConvention(.Stdcall)]
		function Windows.IntBool ConsoleCtrlHandler(int32 ctrlType);
		[CLink, CallingConvention(.Stdcall)]
		static extern Windows.IntBool SetConsoleCtrlHandler(ConsoleCtrlHandler handler, Windows.IntBool addHandler);

		[CLink, CallingConvention(.Stdcall)]
		static extern Windows.IntBool FillConsoleOutputCharacterW(Windows.Handle hConsoleOutput, char16 cCharacter, uint32 nLength, COORD dwWriteCoord, uint32* lpNumberOfCharsWritten);
		[CLink, CallingConvention(.Stdcall)]
		static extern Windows.IntBool FillConsoleOutputAttribute(Windows.Handle hConsoleOutput, uint16 wAttribute, uint32 nLength, COORD dwWriteCoord, uint32* lpNumberOfAttrsWritten);
		[CLink, CallingConvention(.Stdcall)]
		static extern Windows.IntBool SetConsoleCursorPosition(Windows.Handle hConsoleOutput, COORD dwCursorPosition);

		public static this()
		{
			let handle = GetStdHandle(STD_OUTPUT_HANDLE);
			CONSOLE_SCREEN_BUFFER_INFO consoleInfo = .();
			if (GetConsoleScreenBufferInfo(handle, out consoleInfo) != 0)
			{
				sOriginalForegroundColor.ConsoleTextAttribute = (uint8)(consoleInfo.mAttributes & 0xF);
				sOriginalBackgroundColor.ConsoleTextAttribute = (uint8)(consoleInfo.mAttributes >> 4);
			}
			SetConsoleOutputCP(/*CP_UTF8*/65001);
		}

		public static int32 CursorTop
		{
			public get
			{
				let handle = GetStdHandle(STD_OUTPUT_HANDLE);
				CONSOLE_SCREEN_BUFFER_INFO consoleInfo = .();
				GetConsoleScreenBufferInfo(handle,out consoleInfo);
				return consoleInfo.mCursorPosition[1]; //1 = y position
			}
			public set
			{
				//This has to be done afaik to ensure x stays the same
				let handle = GetStdHandle(STD_OUTPUT_HANDLE);
				CONSOLE_SCREEN_BUFFER_INFO consoleInfo = .();
				GetConsoleScreenBufferInfo(handle,out consoleInfo);

				SetConsoleCursorPosition(handle, COORD((.)consoleInfo.mCursorPosition[0], (.)value));
			}
		}
		public static int32 CursorLeft
		{
			public get
			{
				let handle = GetStdHandle(STD_OUTPUT_HANDLE);
				CONSOLE_SCREEN_BUFFER_INFO consoleInfo = .();
				GetConsoleScreenBufferInfo(handle,out consoleInfo);
				return consoleInfo.mCursorPosition[0]; //1 = y position
			}
			public set
			{
				//This has to be done afaik to ensure x stays the same
				let handle = GetStdHandle(STD_OUTPUT_HANDLE);
				CONSOLE_SCREEN_BUFFER_INFO consoleInfo = .();
				GetConsoleScreenBufferInfo(handle,out consoleInfo);

				SetConsoleCursorPosition(handle, COORD((.)value,(.)consoleInfo.mCursorPosition[1]));
			}
		}
#endif

		static StreamWriter OpenStreamWriter(Platform.BfpFileStdKind stdKind, ref StreamWriter outStreamWriter)
		{
			if (outStreamWriter == null)
			{
				Stream stream;
#if BF_TEST_BUILD
				stream = new Test.TestStream();
#else
				FileStream fileStream = new .();
				stream = fileStream;
				if (fileStream.OpenStd(stdKind) case .Err)
				{
					DeleteAndNullify!(fileStream);
					stream = new NullStream();
				}
#endif
				StreamWriter newStreamWriter = new StreamWriter(stream, OutputEncoding ?? Encoding.ASCII, 4096, true);
				newStreamWriter.AutoFlush = true;

				let prevValue = Interlocked.CompareExchange(ref outStreamWriter, null, newStreamWriter);
				if (prevValue != null)
				{
					// This was already set - race condition
					delete newStreamWriter;
					return prevValue;
				}
				return newStreamWriter;
			}
			return outStreamWriter;
		}

		static StreamReader OpenStreamReader(Platform.BfpFileStdKind stdKind, ref StreamReader outStreamReader)
		{
			if (outStreamReader == null)
			{
				FileStream fileStream = new .();
				Stream stream = fileStream;
				if (fileStream.OpenStd(stdKind) case .Ok)
				{
#if BF_PLATFORM_WINDOWS
					
					GetConsoleMode((.)fileStream.Handle, var consoleMode);
					consoleMode &= ~(ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT);
					SetConsoleMode((.)fileStream.Handle, consoleMode);
#endif
				}
				else
				{
					DeleteAndNullify!(fileStream);
					stream = new NullStream();
				}

				StreamReader newStreamReader = new StreamReader(stream, InputEncoding ?? Encoding.ASCII, false, 4096, true);

				let prevValue = Interlocked.CompareExchange(ref outStreamReader, null, newStreamReader);
				if (prevValue != null)
				{
					// This was already set - race condition
					delete newStreamReader;
					return prevValue;
				}
				return newStreamReader;
			}
			return outStreamReader;
		}

		public static volatile StreamWriter mOut ~ delete _;
		public static StreamWriter Out
		{
			get
			{
				return OpenStreamWriter(.Out, ref mOut);
			}
		}

		public static volatile StreamWriter mError ~ delete _;
		public static StreamWriter Error
		{
			get
			{
				return OpenStreamWriter(.Error, ref mError);
			}
		}

		public static volatile StreamReader mIn ~ delete _;
		public static StreamReader In
		{
			get
			{
				return OpenStreamReader(.In, ref mIn);
			}
		}

		public static bool KeyAvailable => In.CanReadNow;
		
		public static Result<char8> Read() => In.Read();

		public static Result<void> ReadLine(String strBuffer)
		{
#if BF_PLATFORM_WINDOWS
			var fs = In.BaseStream as FileStream;
			GetConsoleMode((.)fs.Handle, var consoleMode);
			SetConsoleMode((.)fs.Handle, consoleMode | ENABLE_LINE_INPUT | ENABLE_ECHO_INPUT);
#endif
			var result = In.ReadLine(strBuffer);
#if BF_PLATFORM_WINDOWS
			SetConsoleMode((.)fs.Handle, consoleMode);
#endif

			return result;
		}

		public static Task<String> ReadLineAsync() => In.ReadLineAsync();

		public static Result<void> ReadToEnd(String outText) => In.ReadToEnd(outText);

		public static void Write(StringView line)
		{
			OutString(line);
		}

		public static void Write(StringView fmt, params Object[] args)
		{
			String str = scope String(256);
			str.AppendF(fmt, params args);
			Write(str);
		}
		
		public static void Write(Object obj)
		{
			String str = scope String(256);
			if (obj == null)
				str.Append("null");
			else
				obj.ToString(str);
			Write(str);
		}

		public static void WriteLine()
		{
			OutString("\n");
		}

		public static void WriteLine(StringView line)
		{
			OutString(line);
			OutString("\n");
		}

		public static void WriteLine(StringView fmt, params Object[] args)
		{
			String str = scope String(256);
			str.AppendF(fmt, params args);
			WriteLine(str);
		}
		
		public static void WriteLine(Object obj)
		{
			String str = scope String(256);
			if (obj == null)
				str.Append("null");
			else
				obj.ToString(str);
			WriteLine(str);
		}
		
		public static void ResetColor()
		{
			sForegroundColor = sOriginalForegroundColor;
			sBackgroundColor = sOriginalBackgroundColor;

#if !BF_PLATFORM_WINDOWS
			Write("\x1B[0m");
#endif
		}

		static void SetColors()
		{
#if BF_PLATFORM_WINDOWS
			let handle = GetStdHandle(STD_OUTPUT_HANDLE);
			let fgColor = ForegroundColor.ConsoleTextAttribute;
			let bgColor = BackgroundColor.ConsoleTextAttribute;
			SetConsoleTextAttribute(handle, bgColor * 16 + fgColor);
#else
			Write("\x1B[{}m", ForegroundColor.AnsiCode);
			Write("\x1B[{}m", BackgroundColor.AnsiCode + 10);
#endif
		}

		public static void Clear()
		{
#if BF_PLATFORM_WINDOWS
			Windows.Handle hStdOut;
			CONSOLE_SCREEN_BUFFER_INFO csbi;
			uint32 count;
			uint32 cellCount;
			COORD homeCoords = .(0, 0);
			
			hStdOut = GetStdHandle( STD_OUTPUT_HANDLE );
			if (hStdOut == .InvalidHandle)
				return;

			/* Get the number of cells in the current buffer */
			if (!GetConsoleScreenBufferInfo( hStdOut, out csbi ))
				return;
			cellCount = csbi.mSize[0] * csbi.mSize[1];
			
			/* Fill the entire buffer with spaces */
			if (!FillConsoleOutputCharacterW(
			  hStdOut,
			  ' ',
			  cellCount,
			  homeCoords,
			  &count
			  )) return;

			/* Fill the entire buffer with the current colors and attributes */
			if (!FillConsoleOutputAttribute(
			  hStdOut,
			  csbi.mAttributes,
			  cellCount,
			  homeCoords,
			  &count
			  )) return;

			/* Move the cursor home */
			SetConsoleCursorPosition( hStdOut, homeCoords );
#else
			Write("\x1B[H\x1B[J");
#endif
		}
	}
}
