const {
  initializeTestEnvironment,
  assertSucceeds,
  assertFails,
} = require("@firebase/rules-unit-testing");
const { readFileSync } = require("fs");
const path = require("path");

const PROJECT_ID = "arcangel-4c066";

// UIDs de teste
const TEACHER_UID = "teacher_001";
const STUDENT_UID = "student_001";
const STUDENT2_UID = "student_002";
const STRANGER_UID = "stranger_001";

let testEnv;

beforeAll(async () => {
  const rulesPath = path.resolve(__dirname, "..", "firestore.rules");
  testEnv = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: readFileSync(rulesPath, "utf8"),
    },
  });
});

afterAll(async () => {
  if (testEnv) await testEnv.cleanup();
});

afterEach(async () => {
  await testEnv.clearFirestore();
});

// ─── Helpers ────────────────────────────────────────────────────
function getFirestore(uid) {
  return testEnv.authenticatedContext(uid).firestore();
}

function getUnauthed() {
  return testEnv.unauthenticatedContext().firestore();
}

/** Seed de dados no Firestore (usa contexto admin que bypassa regras) */
async function seedData(callback) {
  await testEnv.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await callback(db);
  });
}

// ═══════════════════════════════════════════════════════════════
// 1. COLEÇÃO Users
// ═══════════════════════════════════════════════════════════════
describe("Users/{userId}", () => {
  test("✅ createProfileIfAbsent — usuário cria seu próprio doc", async () => {
    const db = getFirestore(STUDENT_UID);
    await assertSucceeds(
      db.collection("Users").doc(STUDENT_UID).set({
        display_name: "Aluno Teste",
        email: "aluno@test.com",
        photo_url: "",
        xp: 0,
        level: 1,
        gold: 0,
        faseAtual: 0,
      })
    );
  });

  test("❌ usuário NÃO cria doc de outro", async () => {
    const db = getFirestore(STUDENT_UID);
    await assertFails(
      db.collection("Users").doc(TEACHER_UID).set({
        display_name: "Hack",
        email: "hack@test.com",
      })
    );
  });

  test("✅ setRole — merge:true no próprio doc", async () => {
    // Seed: cria o doc primeiro
    await seedData(async (db) => {
      await db.collection("Users").doc(STUDENT_UID).set({
        display_name: "Aluno",
        email: "aluno@test.com",
        xp: 0,
        level: 1,
        gold: 0,
        faseAtual: 0,
      });
    });

    const db = getFirestore(STUDENT_UID);
    await assertSucceeds(
      db
        .collection("Users")
        .doc(STUDENT_UID)
        .set({ role: "student" }, { merge: true })
    );
  });

  test("✅ getRole — lê próprio doc", async () => {
    await seedData(async (db) => {
      await db.collection("Users").doc(STUDENT_UID).set({
        role: "student",
        email: "a@b.com",
      });
    });

    const db = getFirestore(STUDENT_UID);
    await assertSucceeds(db.collection("Users").doc(STUDENT_UID).get());
  });

  test("❌ lê doc de outro usuário", async () => {
    await seedData(async (db) => {
      await db.collection("Users").doc(TEACHER_UID).set({
        role: "teacher",
        email: "t@b.com",
      });
    });

    const db = getFirestore(STUDENT_UID);
    await assertFails(db.collection("Users").doc(TEACHER_UID).get());
  });

  test("✅ addXp — update no próprio doc", async () => {
    await seedData(async (db) => {
      await db.collection("Users").doc(STUDENT_UID).set({
        xp: 100,
        level: 1,
        gold: 0,
        faseAtual: 0,
      });
    });

    const db = getFirestore(STUDENT_UID);
    // Simula FieldValue.increment — no emulador não funciona diretamente,
    // mas podemos testar o update simples
    await assertSucceeds(
      db.collection("Users").doc(STUDENT_UID).update({ xp: 150 })
    );
  });

  test("❌ não autenticado — bloqueado", async () => {
    const db = getUnauthed();
    await assertFails(db.collection("Users").doc(STUDENT_UID).get());
  });
});

// ═══════════════════════════════════════════════════════════════
// 2. COLEÇÃO Phase (top-level)
// ═══════════════════════════════════════════════════════════════
describe("Phase/{phaseId}", () => {
  test("✅ read — qualquer autenticado lê fases", async () => {
    await seedData(async (db) => {
      await db.collection("Phase").doc("phase1").set({
        name: "Fase 1",
        order: 1,
      });
    });

    const db = getFirestore(STUDENT_UID);
    await assertSucceeds(db.collection("Phase").doc("phase1").get());
  });

  test("✅ create — professor cria fase (saveQuizAsPhase)", async () => {
    // Seed: professor precisa ter role='teacher' no doc Users
    await seedData(async (db) => {
      await db.collection("Users").doc(TEACHER_UID).set({
        role: "teacher",
        email: "prof@test.com",
      });
    });

    const db = getFirestore(TEACHER_UID);
    await assertSucceeds(
      db.collection("Phase").doc("newPhase").set({
        classroomId: "classroom1",
        name: "Quiz 1",
        order: 1,
      })
    );
  });

  test("❌ create — aluno NÃO cria fase", async () => {
    await seedData(async (db) => {
      await db.collection("Users").doc(STUDENT_UID).set({
        role: "student",
        email: "aluno@test.com",
      });
    });

    const db = getFirestore(STUDENT_UID);
    await assertFails(
      db.collection("Phase").doc("hackPhase").set({
        name: "Hack",
        order: 1,
      })
    );
  });

  test("❌ create — usuário sem role NÃO cria fase", async () => {
    await seedData(async (db) => {
      await db.collection("Users").doc(STRANGER_UID).set({
        email: "novo@test.com",
        // SEM role
      });
    });

    const db = getFirestore(STRANGER_UID);
    await assertFails(
      db.collection("Phase").doc("hackPhase").set({
        name: "Hack",
        order: 1,
      })
    );
  });
});

// ═══════════════════════════════════════════════════════════════
// 3. COLEÇÃO Questions (top-level)
// ═══════════════════════════════════════════════════════════════
describe("Questions/{questionId}", () => {
  test("✅ read — qualquer autenticado lê", async () => {
    await seedData(async (db) => {
      await db.collection("Questions").doc("q1").set({
        text: "2+2?",
        options: ["3", "4"],
        correct_answer: 1,
      });
    });

    const db = getFirestore(STUDENT_UID);
    await assertSucceeds(db.collection("Questions").doc("q1").get());
  });

  test("✅ create — professor cria questão", async () => {
    await seedData(async (db) => {
      await db.collection("Users").doc(TEACHER_UID).set({
        role: "teacher",
        email: "prof@test.com",
      });
    });

    const db = getFirestore(TEACHER_UID);
    await assertSucceeds(
      db.collection("Questions").doc("newQ").set({
        text: "Capital do Brasil?",
        options: ["SP", "Brasília"],
        correct_answer: 1,
      })
    );
  });

  test("❌ create — aluno NÃO cria questão top-level", async () => {
    await seedData(async (db) => {
      await db.collection("Users").doc(STUDENT_UID).set({
        role: "student",
        email: "aluno@test.com",
      });
    });

    const db = getFirestore(STUDENT_UID);
    await assertFails(
      db.collection("Questions").doc("hackQ").set({
        text: "hack",
      })
    );
  });
});

// ═══════════════════════════════════════════════════════════════
// 4. COLEÇÃO Classrooms
// ═══════════════════════════════════════════════════════════════
describe("Classrooms/{classroomId}", () => {
  // Seed padrão: professor com role, aluno com role
  async function seedUsers() {
    await seedData(async (db) => {
      await db.collection("Users").doc(TEACHER_UID).set({
        role: "teacher",
        email: "prof@test.com",
      });
      await db.collection("Users").doc(STUDENT_UID).set({
        role: "student",
        email: "aluno@test.com",
      });
      await db.collection("Users").doc(STUDENT2_UID).set({
        role: "student",
        email: "aluno2@test.com",
      });
    });
  }

  async function seedClassroom(extraFields = {}) {
    await seedData(async (db) => {
      await db
        .collection("Classrooms")
        .doc("class1")
        .set({
          code: "ABC123",
          name: "Turma Teste",
          description: "Desc",
          teacherId: TEACHER_UID,
          studentIds: [STUDENT_UID],
          isActive: true,
          ...extraFields,
        });
    });
  }

  // ─── CREATE ─────────────────────────────────────────────────
  test("✅ createClassroom — professor cria sala", async () => {
    await seedUsers();
    const db = getFirestore(TEACHER_UID);
    await assertSucceeds(
      db.collection("Classrooms").doc("newClass").set({
        code: "XYZ789",
        name: "Nova Turma",
        description: "Desc",
        teacherId: TEACHER_UID,
        studentIds: [],
        isActive: true,
      })
    );
  });

  test("❌ createClassroom — aluno NÃO cria sala", async () => {
    await seedUsers();
    const db = getFirestore(STUDENT_UID);
    await assertFails(
      db.collection("Classrooms").doc("hackClass").set({
        code: "HACK01",
        name: "Hack",
        teacherId: STUDENT_UID,
        studentIds: [],
        isActive: true,
      })
    );
  });

  test("❌ createClassroom — professor cria sala com teacherId de outro", async () => {
    await seedUsers();
    const db = getFirestore(TEACHER_UID);
    await assertFails(
      db.collection("Classrooms").doc("spoofClass").set({
        code: "SPOOF1",
        name: "Spoof",
        teacherId: "other_teacher_uid",
        studentIds: [],
        isActive: true,
      })
    );
  });

  // ─── READ ───────────────────────────────────────────────────
  test("✅ fetchByCode — qualquer autenticado pode ler (necessário para join)", async () => {
    await seedUsers();
    await seedClassroom();

    // Aluno 2 que NÃO está na sala pode ler (para verificar código)
    const db = getFirestore(STUDENT2_UID);
    await assertSucceeds(db.collection("Classrooms").doc("class1").get());
  });

  test("✅ fetchTeacherClassrooms — professor lê suas salas", async () => {
    await seedUsers();
    await seedClassroom();

    const db = getFirestore(TEACHER_UID);
    await assertSucceeds(db.collection("Classrooms").doc("class1").get());
  });

  test("✅ fetchStudentClassroom — aluno lê sua sala", async () => {
    await seedUsers();
    await seedClassroom();

    const db = getFirestore(STUDENT_UID);
    await assertSucceeds(db.collection("Classrooms").doc("class1").get());
  });

  test("❌ read — não autenticado bloqueado", async () => {
    await seedClassroom();
    const db = getUnauthed();
    await assertFails(db.collection("Classrooms").doc("class1").get());
  });

  // ─── UPDATE (professor) ─────────────────────────────────────
  test("✅ updateClassroom — professor atualiza nome/descrição", async () => {
    await seedUsers();
    await seedClassroom();

    const db = getFirestore(TEACHER_UID);
    await assertSucceeds(
      db.collection("Classrooms").doc("class1").update({
        name: "Nome Atualizado",
        description: "Nova desc",
      })
    );
  });

  test("❌ updateClassroom — aluno NÃO altera nome", async () => {
    await seedUsers();
    await seedClassroom();

    const db = getFirestore(STUDENT_UID);
    await assertFails(
      db.collection("Classrooms").doc("class1").update({
        name: "Hackeado",
      })
    );
  });

  // ─── UPDATE (join/leave) ────────────────────────────────────
  test("✅ joinClassroom — aluno adiciona seu uid ao studentIds", async () => {
    await seedUsers();
    // Sala SEM o student2
    await seedClassroom({ studentIds: [STUDENT_UID] });

    const db = getFirestore(STUDENT2_UID);
    // Simula FieldValue.arrayUnion — no emulador, setamos o array completo
    await assertSucceeds(
      db.collection("Classrooms").doc("class1").update({
        studentIds: [STUDENT_UID, STUDENT2_UID],
      })
    );
  });

  test("✅ leaveClassroom — aluno remove seu uid do studentIds", async () => {
    await seedUsers();
    await seedClassroom({ studentIds: [STUDENT_UID, STUDENT2_UID] });

    const db = getFirestore(STUDENT2_UID);
    // Simula FieldValue.arrayRemove — o resultado final não tem student2
    await assertSucceeds(
      db.collection("Classrooms").doc("class1").update({
        studentIds: [STUDENT_UID],
      })
    );
  });

  // ─── DELETE ─────────────────────────────────────────────────
  test("✅ delete — professor dono deleta sala", async () => {
    await seedUsers();
    await seedClassroom();

    const db = getFirestore(TEACHER_UID);
    await assertSucceeds(db.collection("Classrooms").doc("class1").delete());
  });

  test("❌ delete — aluno NÃO deleta sala", async () => {
    await seedUsers();
    await seedClassroom();

    const db = getFirestore(STUDENT_UID);
    await assertFails(db.collection("Classrooms").doc("class1").delete());
  });
});

// ═══════════════════════════════════════════════════════════════
// 5. SUBCOLEÇÃO Classrooms/{id}/questions
// ═══════════════════════════════════════════════════════════════
describe("Classrooms/{id}/questions/{qId}", () => {
  async function seedAll() {
    await seedData(async (db) => {
      await db.collection("Users").doc(TEACHER_UID).set({
        role: "teacher",
        email: "prof@test.com",
      });
      await db.collection("Users").doc(STUDENT_UID).set({
        role: "student",
        email: "aluno@test.com",
      });
      await db.collection("Classrooms").doc("class1").set({
        code: "ABC123",
        name: "Turma",
        teacherId: TEACHER_UID,
        studentIds: [STUDENT_UID],
        isActive: true,
      });
      await db
        .collection("Classrooms")
        .doc("class1")
        .collection("questions")
        .doc("q1")
        .set({
          text: "2+2?",
          options: ["3", "4"],
          correct_answer: 1,
          order: 1,
        });
    });
  }

  test("✅ professor cria questão na subcoleção", async () => {
    await seedAll();
    const db = getFirestore(TEACHER_UID);
    await assertSucceeds(
      db
        .collection("Classrooms")
        .doc("class1")
        .collection("questions")
        .doc("q2")
        .set({
          text: "Nova questão",
          options: ["a", "b"],
          correct_answer: 0,
          order: 2,
        })
    );
  });

  test("❌ aluno NÃO cria questão", async () => {
    await seedAll();
    const db = getFirestore(STUDENT_UID);
    await assertFails(
      db
        .collection("Classrooms")
        .doc("class1")
        .collection("questions")
        .doc("hackQ")
        .set({
          text: "Hack",
        })
    );
  });

  test("✅ aluno lê questões da sua sala", async () => {
    await seedAll();
    const db = getFirestore(STUDENT_UID);
    await assertSucceeds(
      db
        .collection("Classrooms")
        .doc("class1")
        .collection("questions")
        .doc("q1")
        .get()
    );
  });

  test("❌ estranho NÃO lê questões", async () => {
    await seedAll();
    await seedData(async (db) => {
      await db.collection("Users").doc(STRANGER_UID).set({
        role: "student",
        email: "stranger@test.com",
      });
    });
    const db = getFirestore(STRANGER_UID);
    await assertFails(
      db
        .collection("Classrooms")
        .doc("class1")
        .collection("questions")
        .doc("q1")
        .get()
    );
  });

  test("✅ professor atualiza questão", async () => {
    await seedAll();
    const db = getFirestore(TEACHER_UID);
    await assertSucceeds(
      db
        .collection("Classrooms")
        .doc("class1")
        .collection("questions")
        .doc("q1")
        .update({ text: "Atualizado" })
    );
  });

  test("✅ professor deleta questão", async () => {
    await seedAll();
    const db = getFirestore(TEACHER_UID);
    await assertSucceeds(
      db
        .collection("Classrooms")
        .doc("class1")
        .collection("questions")
        .doc("q1")
        .delete()
    );
  });
});

// ═══════════════════════════════════════════════════════════════
// 6. SUBCOLEÇÃO Classrooms/{id}/results
// ═══════════════════════════════════════════════════════════════
describe("Classrooms/{id}/results/{studentId}", () => {
  async function seedAll() {
    await seedData(async (db) => {
      await db.collection("Users").doc(TEACHER_UID).set({
        role: "teacher",
        email: "prof@test.com",
      });
      await db.collection("Users").doc(STUDENT_UID).set({
        role: "student",
        email: "aluno@test.com",
      });
      await db.collection("Users").doc(STUDENT2_UID).set({
        role: "student",
        email: "aluno2@test.com",
      });
      await db.collection("Classrooms").doc("class1").set({
        code: "ABC123",
        name: "Turma",
        teacherId: TEACHER_UID,
        studentIds: [STUDENT_UID],
        isActive: true,
      });
    });
  }

  test("✅ submitResult — aluno submete SEU resultado", async () => {
    await seedAll();
    const db = getFirestore(STUDENT_UID);
    await assertSucceeds(
      db
        .collection("Classrooms")
        .doc("class1")
        .collection("results")
        .doc(STUDENT_UID)
        .set({
          studentName: "Aluno Teste",
          totalQuestions: 10,
          correctAnswers: 8,
          completedAt: new Date(),
        })
    );
  });

  test("❌ submitResult — aluno NÃO submete resultado de outro", async () => {
    await seedAll();
    const db = getFirestore(STUDENT_UID);
    await assertFails(
      db
        .collection("Classrooms")
        .doc("class1")
        .collection("results")
        .doc(STUDENT2_UID)
        .set({
          studentName: "Hack",
          totalQuestions: 10,
          correctAnswers: 10,
          completedAt: new Date(),
        })
    );
  });

  test("❌ submitResult — aluno não membro NÃO submete", async () => {
    await seedAll();
    const db = getFirestore(STUDENT2_UID);
    await assertFails(
      db
        .collection("Classrooms")
        .doc("class1")
        .collection("results")
        .doc(STUDENT2_UID)
        .set({
          studentName: "Outsider",
          totalQuestions: 10,
          correctAnswers: 10,
          completedAt: new Date(),
        })
    );
  });

  test("✅ fetchResults — professor lê resultados", async () => {
    await seedAll();
    await seedData(async (db) => {
      await db
        .collection("Classrooms")
        .doc("class1")
        .collection("results")
        .doc(STUDENT_UID)
        .set({
          studentName: "Aluno",
          totalQuestions: 10,
          correctAnswers: 7,
        });
    });

    const db = getFirestore(TEACHER_UID);
    await assertSucceeds(
      db
        .collection("Classrooms")
        .doc("class1")
        .collection("results")
        .doc(STUDENT_UID)
        .get()
    );
  });

  test("✅ fetchResults — aluno membro lê resultados", async () => {
    await seedAll();
    await seedData(async (db) => {
      await db
        .collection("Classrooms")
        .doc("class1")
        .collection("results")
        .doc(STUDENT_UID)
        .set({
          studentName: "Aluno",
          totalQuestions: 10,
          correctAnswers: 7,
        });
    });

    const db = getFirestore(STUDENT_UID);
    await assertSucceeds(
      db
        .collection("Classrooms")
        .doc("class1")
        .collection("results")
        .doc(STUDENT_UID)
        .get()
    );
  });

  test("❌ fetchResults — estranho NÃO lê resultados", async () => {
    await seedAll();
    await seedData(async (db) => {
      await db
        .collection("Classrooms")
        .doc("class1")
        .collection("results")
        .doc(STUDENT_UID)
        .set({
          studentName: "Aluno",
          totalQuestions: 10,
          correctAnswers: 7,
        });
    });

    const db = getFirestore(STRANGER_UID);
    await assertFails(
      db
        .collection("Classrooms")
        .doc("class1")
        .collection("results")
        .doc(STUDENT_UID)
        .get()
    );
  });
});
