subprojects {
    afterEvaluate {
        if (project.hasProperty("android")) {
            val android = project.extensions.getByName("android") as com.android.build.gradle.BaseExtension
            
            // Correction pour Paystack
            // Donne le vrai nom de Paystack si celui-ci est manquant
            if (android.namespace == null) {
                if (project.name == "flutter_paystack") {
                    android.namespace = "co.paystack.flutterpaystack"
                } else {
                    android.namespace = "online.serviceproci.app"
                }
            }

            android.compileOptions {
                sourceCompatibility = JavaVersion.VERSION_1_8
                targetCompatibility = JavaVersion.VERSION_1_8
            }
            
            // On utilise compilerOptions ici pour plaire à Gradle
            tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
                compilerOptions {
                    jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_1_8)
                }
            }
        }
    }
}