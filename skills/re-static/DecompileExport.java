// DecompileExport.java — Ghidra headless postScript: decompile every function to C.
// Writes the C to the path in the GHIDRA_OUT_C environment variable.
// Invoked by ghidra_decompile.sh:  analyzeHeadless ... -postScript DecompileExport.java
//
// Why Java (not a .py script): Ghidra 12 dropped the bundled Jython interpreter;
// .py scripts now require PyGhidra (CPython + JPype), which is not installed.
// Java GhidraScripts are compiled in-process by the JDK and always work headless.
// @category vibe-reverse
import java.io.PrintWriter;
import ghidra.app.script.GhidraScript;
import ghidra.app.decompiler.DecompInterface;
import ghidra.app.decompiler.DecompileResults;
import ghidra.program.model.listing.Function;
import ghidra.program.model.listing.FunctionManager;

public class DecompileExport extends GhidraScript {
    @Override
    public void run() throws Exception {
        String outPath = System.getenv("GHIDRA_OUT_C");
        if (outPath == null || outPath.isEmpty()) {
            outPath = "/tmp/ghidra.c";
        }

        DecompInterface decomp = new DecompInterface();
        decomp.openProgram(currentProgram);          // currentProgram: GhidraScript field
        FunctionManager fm = currentProgram.getFunctionManager();

        PrintWriter out = new PrintWriter(outPath);
        try {
            out.println("// Ghidra decompilation of " + currentProgram.getName());
            out.println();
            for (Function func : fm.getFunctions(true)) {   // true = forward address order
                if (monitor.isCancelled()) {                // monitor: GhidraScript field
                    break;
                }
                DecompileResults res = decomp.decompileFunction(func, 60, monitor);
                if (res != null && res.decompileCompleted()) {
                    out.println(res.getDecompiledFunction().getC());
                } else {
                    out.println("// [decompile failed] " + func.getName()
                            + " @ " + func.getEntryPoint());
                    out.println();
                }
            }
        } finally {
            out.close();
            decomp.dispose();
        }
    }
}
